#! /usr/bin/python3
"""
Common corpus management

changelog v0.3: No fixed "corpus_home" container
                (must be specified at init)
                No workshop_home either (this script_dir instead)
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.3"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

from os              import path, mkdir, rename
from shutil          import rmtree, move
from re              import match, search, sub, escape, MULTILINE
from csv             import DictReader
from collections     import defaultdict
from subprocess      import call
from json            import dump, load

# pour utilisation autonome
# corpusdirs.py new_corpus_name -t info_table.tsv
from argparse        import ArgumentParser, RawDescriptionHelpFormatter
from sys             import argv


# imports locaux
try:
	# CHEMIN 1 cas de figure du dossier utilisé comme librairie
	#          au sein d'un package plus grand (exemple: bib-adapt-corpus)
	from libconsulte import api
	from libconsulte import field_value_lists
	# =<< target_language_values, target_scat_values,
	#     target_genre_values, target_date_ranges
except ImportError:
	try:
		# CHEMIN 2: cas de figure d'un appel depuis le dossier courant
		#           exemple: on veut juste lancer le sampler tout seul
		import api
		import field_value_lists
		
	# cas de figure où il n'y a vraiment rien
	except ImportError:
		print("ERR: Les modules 'api.py' et 'field_value_lists.py' doivent être placés à côté du script corpusdirs.py ou dans un dossier du PYTHONPATH, pour sa bonne execution...")
		exit(1)



# Infos structurelles de corpus par défaut
BSHELVES = {
  # basic set ----------------------------------------------------------
  'PDF0': {'d':'A-pdfs',       'ext':'.pdf',      'api':'fulltext/pdf'},
  'XMLN': {'d':'B-xmlnatifs',  'ext':'.xml',      'api':'metadata/xml'},
  'GTEI': {'d':'C-goldxmltei', 'ext':'.tei.xml'},
  # --------------------------------------------------------------------
}

# pour trouver etc/dtdmashup et etc/pub2TEI installés avec ce fichier
THIS_SCRIPT_DIR = path.dirname(path.realpath(__file__))

class Corpus(object):
	"""
	A collection of docs with their metadata
	and their diverse input text formats.
	
	Usual slots:

	 -self.meta
	 -self.shelfs
	
	2nd step
	 -self.cols
	 -self.fileids
	"""
	
	# ------------------------------------------------------------
	#             C O R P U S    I N I T
	# ------------------------------------------------------------

	# £TODO absolument une dir extraite de s1 sous la forme read_dir
	def __init__(self, ko_name, new_infos=None, new_home=None,
					read_dir=False, corpus_type='gold',
						verbose=False, shelves_struct=None):
		"""
		2 INPUT modes
		  -IN: *new_infos* : a metadata table (eg sampler output)
		                  (no fulltexts yet, no workdir needed)
		      + *new_home* : the container dir (ex: '.')
		
		  -IN: *read_dir* : path to an existing Corpus dir
		                  (with data/ and meta/ subdirs, etc.)
		      + *new_home* : the container dir (ex: '.')
		
		In both modes: *new_home* is THE_CONTAINER DIR (private _home)
		               + *shtruct* is A_SHELVES_STRUCTURE (private _shtruct)
		                      => shtruct = BSHELVES (Corpus obj) 
		                      => shtruct = UPDATED_SHELVES (TrainingCorpus obj)
		                 + *type* option 
		                      => type = 'gold' (Corpus obj) 
		                      => type = 'train' (TrainingCorpus obj)
		                   + *verbose* option (for init)
		
		OUT: Corpus instance with:
			self.bnames
			-----------
			   =  basenames created for each file (from new_infos[id])
			
			self.shelfs
			-----------
			   ~ structured persistance layers (currently fs based)
			   => provides shelfs subdir, file ext and fileids(shname)
			
			and also: self.meta    self.cols     self.name     self.cdir
			          ---------    ---------     ---------     ---------
		"""
		if not new_home or not path.exists(new_home):
			print("Please provide an existing container directory to save the corpus directory into (current:%s)" % new_home)
			raise FileNotFoundError(new_home)
		
		# VAR 1: **home** our absolute container address ----------
		# (version absolue du chemin de base indiqué à l'initialisation)
		self._home = path.abspath(new_home)
		
		# VAR 2: **shtruct** the structure of "shelves" (subdirs) -
		# (structure for each possible shelf of this instance)
		
		# 4 possibilités ici :(
		# (1/4) si lecture ET l'argument shelves_struct est à None:
		# => on a une lecture simple comme take_set
		if read_dir and not shelves_struct:
			# reprise table persistante shelves_map telle qu'elle était la dernière fois
			# mini-TODO: factoriser la vérif de read_dir qui est plus loin pour cdir...
			map_path = path.join(read_dir,'meta','shelves_map.json')
			shmap = open(map_path,'r')
			self._shtruct = load(shmap)
			shmap.close()
		
		# (2/4) ==> on a une lecture + extension
		#           (le corpus pourra avoir de nouvelles étagères)
		#           (on est sans doute appelés comme super.__init__())
		elif read_dir and shelves_struct:
			# la table la plus récente a dû être fournie
			self._shtruct = shelves_struct
		
		# (3/4) et (4/4)
		# => *initialisations* avec ou sans valeur fournie
		else:
			# initialisation standard
			if not shelves_struct:
				# on prend la valeur par défaut
				self._shtruct = BSHELVES
			
			# initialisation directement étendue
			else:
				self._shtruct = shelves_struct



		# VAR 3: >> name << should be usable in a fs and without accents (for saxonb-xslt)
		if type(ko_name) == str and match(r'[_0-9A-Za-z-]+', ko_name):
			self.name = ko_name
		else:
			raise TypeError("new Corpus('%s') needs a name str matching /^[0-9A-Za-z_-]+$/ as 1st arg" % ko_name)
		
		# VAR 4: **cdir** new dir for this corpus and subdirs ----------
		if not read_dir:
			self.cdir = path.join(new_home, ko_name)
			mkdir(self.cdir)
			mkdir(path.join(self.cdir,"data"))    # pour les documents
			mkdir(path.join(self.cdir,"meta"))    # pour les tables etc.
		else:
			# remove any trailing slash
			read_dir = sub(r'/+$', '', read_dir)
			read_root, read_subdir = path.split(read_dir)
			if not len(read_root):
				read_root='.'
			
			# check correct corpora dir
			if not path.samefile(read_root, new_home):
				print("WARN: reading a corpus in dir '%s' instead of default '%s'"
				      % (read_root, new_home) )
			
			# check correct corpus dir name
			if read_subdir != ko_name:
				raise TypeError("""
ERROR -- Corpus(__init__ from dir): 
=> corpus name '%s' should be same as your dir %s <="""
				 % (ko_name, read_subdir) )
			else:
				self.cdir = read_dir
				
				# find corresponding infos
				infos_path = path.join(self.cdir,'meta','infos.tab')
				try:
					fi = open(infos_path,'r')    # todo idem pour triggers
				except FileNotFoundError as fnf_err:
					fnf_err.pi_mon_rel_path = path.join(ko_name, 'meta','infos.tab')
					raise fnf_err
				# read in from meta/infos.tab to RAM
				new_infos = [l.rstrip() for l in fi.readlines()]
				fi.close()
			
			if verbose:
				print(".rawinfos << %s" % infos_path)
		
		
		# VAR 5: >> shelfs <<   (index de flags pour "sous-dossiers par format")
		#                           shelfs refer to dirs of docs
		#                           of a given format
		self.shelfs = {}
		# 'shelf_triggers.json' <=> presence/absence flags for each shelf
		trig_path = path.join(self.cdir,'meta','shelf_triggers.json')
		
		if read_dir:
			# initialize shelfs from meta shelf_triggers.json
			try:
				triggrs = open(trig_path,'r')
				self.shelfs = load(triggrs)     # json.load
				triggrs.close()
			# or old way: initialize shelfs from subdir presence
			except:
				print("No saved shelf_triggers.json, regenerating from dirs")
				for shname in self._shtruct:
					if path.exists(self.shelf_path(shname)):
						self.shelfs[shname] = True
					else:
						self.shelfs[shname] = False
				# persistence of shelf presence/absence flags
				self.save_shelves_status()
			
			# ajout pour un corpus étendu:
			# initialize all other new shelves as empty
			for shname in self._shtruct:
				if shname not in self.shelfs:
					self.shelfs[shname] = False
		
		else:
			# initialize empty
			for shname in self._shtruct:
				self.shelfs[shname] = False
				# ex: {
				# 	'PDF0' : False,       # later: self.shelf[shname] to True
				# 	'NXML' : False,       # if and only if the fulltext files
				# 	'GTEI' : False,       # have already been placed in their
				# }                      # appropriate subdir


		# VARS 6 and 7: >> meta << and >> cols << lookup tables --------
		if new_infos:
			# as source in usual INIT mode: directly with new_infos lines
			# + also go here in READ mode with info lines retrieved from fs
			# (only exception is empty inits)
			
			# a simple csv reader (headers as in sampler.STD_MAP)
			records_obj = DictReader(new_infos, delimiter='\t')
			
			# required headers: istex_id, corpus
			
			# ----- metadata
			# meta: table where each rec 
			#       is a dict with always
			#       the same keys
			self.meta = [rec for rec in records_obj]
			
			# cols: same but transposed 
			#       for column access
			self.cols = self._read_columns()
			
			if verbose:
				print(".cols:")
				print("  ├──['pub_year'] --> %s" % self.cols['pub_year'][0:3] + '..')
				print("  ├──['title']    --> %s" % [s[0:10]+'..' for s in self.cols['title'][0:3]] + '..')
				print("  └──%s --> ..." % [cname for cname in self.cols if cname not in ['pub_year','title']])
			
			# ----- fileids
			# VARS 8: >> bnames << basenames for persistance slots
			my_ids = self.cols['istex_id']
			my_lot = self.cols['corpus']
			self.bnames = []
			for i,did in enumerate(my_ids):
				self.bnames.append(my_lot[i]+'-'+did)
				# ex: wil-0123456789ABCDEF0123456789ABCDEF01234567
			
			# all saved files pertaining to the same document object
			# will thus share the same basename, with a different .ext
			# usage: [id+lot =>] basenames [=> fileids == fspaths]
			
			if not read_dir:
				# SAVE META: infos to filesystem
				tab_fh = open(path.join(self.cdir,'meta','infos.tab'),'w')
				tab_fh.write("\n".join(new_infos) + "\n")
				tab_fh.close()
				# SAVE META: basenames
				bn_fh = open(path.join(self.cdir,'meta','basenames.ls'),'w')
				bn_fh.write("\n".join(self.bnames) + "\n")
				bn_fh.close()
				# SAVE META: shelfs (flags if some fulltexts already present)
				triggrs = open(trig_path,'w')
				dump(self.shelfs, triggrs, indent=2)     # json.dump
				triggrs.close()
		
				# £TODO ici tree.json DATE x PUB
			
			# VARS 9: >> size <<  (nombre de docs dans 1 étagère)
			self.size = len(self.bnames)
			
		else:
			self.meta = None
			self.cols = None
			self.bnames = None
			self.size = 0
		
		# VARS 10: >> ctype << (type de corpus)
		# (trace volontairement en dur à l'initialisation)
		# (à réécrire si et seulement si réinstancié en corpus étendu)
		self.ctype = corpus_type
		touch_type = open(path.join(self.cdir,"meta","corpus_type.txt"), 'w')
		print(self.ctype+'\n', file=touch_type)
		touch_type.close()
		
		# print triggers (active/passive shelves)
		if verbose:
			self.print_corpus_info()
		# si on a eu un extension
		# (sera différente si et seulement si init objet fille)
		self._save_shelves_map()

	# ------------------------------------------------------------
	#             C O R P U S    A C C E S S O R S
	# ------------------------------------------------------------
	
	# todo memoize
	def shelf_path(self, my_shelf):
		"""
		Returns the standard dir for a shelf: 
		   >> $cdir/data/$shsubdir <<
		(it contains the files of a given format)
		"""
		if my_shelf in self._shtruct:
			shsubdir = self._shtruct[my_shelf]['d']
			shpath = path.join(self.cdir, 'data', shsubdir)
			return shpath
		else:
			print(self._shtruct) # pour debug
			raise KeyError("Unknown shelf %s" % my_shelf)
	
	def filext(self, the_shelf):
		"""
		File extension for this shelf
		"""
		# file extension
		return self._shtruct[the_shelf]['ext']
	
	
	def origin(self, the_shelf):
		"""
		If exists, theoretical api route origin
		or processor command origin
		for this shelf's contents
		"""
		# api_route
		if 'api' in self._shtruct[the_shelf]:
			return self._shtruct[the_shelf]['api']
		elif 'cmd' in self._shtruct[the_shelf]:
			return self._shtruct[the_shelf]['cmd']
		else:
			return None
	
	def fileid(self, the_bname, the_shelf, 
				shext=None, shpath=None):
		"""
		Filesystem path of a given doc in a shelf
		(nb: doesn't check if doc is there)
		
		A utiliser en permanence
		"""
		# file extension
		if not shext:
			shext = self._shtruct[the_shelf]['ext']
		# standard shelf dir
		if not shpath:
			shpath = self.shelf_path(the_shelf)
		
		# real file path
		return path.join(shpath, the_bname+shext)

	def fileids(self, my_shelf):
		"""
		A list of theoretical files in a given shelf
		(filesystem paths)
		"""
		if my_shelf in self._shtruct:
			shext = self._shtruct[my_shelf]['ext']
			shpath = self.shelf_path(my_shelf)
			# faster than with simpler [_fileid(bn, my_shelf) for bn..]
			return [self.fileid(bn, my_shelf, shpath=shpath, shext=shext) 
										for bn in self.bnames]
		else:
			print("WARN: Unknown shelf type %s" % my_shelf)
			return None

	def _read_columns(self):
		"""
		Function for index transposition (used in __init__: self.cols)
		Records are an array of dicts, that all have the same keys 
		(info lines)
		We return a dict of arrays, that all have the same length.
		(=> info columns)
		"""
		records = self.meta
		cols = defaultdict(list)
		try:
			for this_col in records[0].keys():
				colarray = [rec_i[this_col] for rec_i in records]
				cols[this_col] = colarray
		except IndexError as e:
			raise(TypeError('Each record in the input array must contain same keys (aka "column names")'))
		return cols
	
	def assert_docs(self, shname):
		"""
		Just sets the shelf flag to true
		(we assume the files have been put there)
		(and the fileids are automatically known from bnames + shelf_struct)
		"""
		if shname in self._shtruct:
			self.shelfs[shname] = True
	
	def save_shelves_status(self):
		"""
		Persistence for asserted shelves and their map
		"""
		trig_path = path.join(self.cdir,'meta','shelf_triggers.json')
		triggrs = open(trig_path,'w')
		dump(self.shelfs, triggrs, indent=2)     # json.dump
		triggrs.close()
	
	def _save_shelves_map(self):
		"""
		Persistence for possible shelves and their structural info.
		"""
		map_path = path.join(self.cdir,'meta','shelves_map.json')
		# write shtruct to meta/shelves_map.json
		shmap = open(map_path,'w')
		dump(self._shtruct, shmap, indent=2)      # json.dump
		shmap.close()
	
	
	def got_shelves(self):
		"""
		The list of present fulltexts shelves.
		"""
		all_sorted = sorted(self._shtruct, key=lambda x:self._shtruct[x]['d'])
		got_shelves = [sh for sh in all_sorted if self.shelfs[sh]]
		return got_shelves
	
	def print_corpus_info(self):
		"""
		Prints a short list of possible shelves with ON/off status
		       and basic info: corpus_name and size
		"""
		print("======= CORPUSDIRS  [%s]  =======" % self.name)
		triggers_dirs = []
		for shelf, bol in self.shelfs.items():
			on_off = ' ON' if bol else 'off'
			ppdir = self._shtruct[shelf]['d']
			triggers_dirs.append([ppdir,on_off])
		for td in sorted(triggers_dirs):
			print("  > %-3s  --- %s" % (td[1], td[0]))
		print("\n=====( SIZE: %i docs x %i shelfs )=====\n" % (self.size, len(self.shelfs)))
	
	# ------------------------------------------------------------
	#         C O R P U S   B A S E   C O N V E R T E R S
	# ------------------------------------------------------------
	# Most common corpus actions
	#
	# (manipulate docs and create new dirs with the result)
	
	# GOLD NATIVE XML
	def dtd_repair(self, dtd_prefix=None, our_home=None, debug_lvl=0):
		"""
		Linking des dtd vers nos dtd stockées dans /etc
		ou dans un éventuel autre dossier dtd_prefix
		"""
		if not dtd_prefix:
			dtd_prefix = path.abspath(path.join(THIS_SCRIPT_DIR,'etc','dtd_mashup'))
			if debug_lvl >= 1:
				print("DTD_REPAIR: new dtd_prefix: '%s'" % dtd_prefix)
		
		# corpus home
		if not our_home:
			our_home = self._home
		
		# ssi dossier natif présent
		if self.shelfs['XMLN']:
			todofiles = self.fileids(my_shelf="XMLN")
			
			nb_missing = 0
			nb_uerrors = 0
			nb_no_dtd_wiley = 0
			nb_no_dtd_other = 0
			
			# temporary repaired_dir
			repaired_dir = path.join(self.cdir, 'data', 'with_dtd_repaired')
			if path.exists(repaired_dir):
				print ('DTD_REPAIR: overwriting previous aborted reparation')
			else:
				mkdir(repaired_dir)
			
			for fi in todofiles:
				try:
					fh = open(fi, 'r')
				except FileNotFoundError as fnfe:
					nb_missing += 1
					print("DTD_REPAIR (skip) missing source file %s" % fi)
					continue
				try:
					long_str = fh.read()
				except UnicodeDecodeError as ue:
					nb_uerrors += 1
					print("DTD_REPAIR (skip) UTF-8 decode error in input file %s" % fi)
					# moving the file as it is and skipping reparation
					move(fi, path.join(repaired_dir,path.basename(fi)))
					continue
					# £TODO alternative: add to error/ignore list with the object
				fh.close()
				
				# splits a doctype declaration in 3 elements
				 # lhs + '"' + uri.dtd + '"' + rhs
				m = search(
				  r'(<!DOCTYPE[^>]+(?:PUBLIC|SYSTEM)[^>]*)"([^"]+\.dtd)"((?:\[[^\]]*\])?[^>]*>)',
					long_str, 
					MULTILINE
					)
				
				if m:
					# kept for later
					left_hand_side = m.groups()[0]
					right_hand_side = m.groups()[2]
					
					# we replace the middle group uri with our prefix + old dtd_basename
					dtd_uri = m.groups()[1]
					# print ('FOUND:' + dtd_uri)
					dtd_basename = path.basename(dtd_uri)
					new_dtd_path = dtd_prefix + '/' + dtd_basename
					
					# print(new_dtd_path)
					
					# substitute a posteriori
					original_declaration = left_hand_side+'"'+dtd_uri+'"'+right_hand_side
					new_declaration = left_hand_side+'"'+new_dtd_path+'"'+right_hand_side
					new_str = sub(escape(original_declaration), new_declaration, long_str)
					
					# save
					outfile = open(path.join(repaired_dir,path.basename(fi)), 'w')
					outfile.write(new_str)
					outfile.close()
				else:
					if not search(r'wiley', long_str):
						# wiley often has no DTD declaration, just ns
						nb_no_dtd_other += 1
						print('DTD_REPAIR (skip) no match on %s' % fi)
					else:
						nb_no_dtd_wiley += 1
					# save as is
					filename = path.basename(fi)
					outfile = open(path.join(repaired_dir,path.basename(fi)), 'w')
					outfile.write(long_str)
					outfile.close()
			
			# rename to std dir
			orig_dir = self.shelf_path("XMLN")
			if debug_lvl >= 2:
				print ("DTD_REPAIR: replacing native XMLs in %s by temporary contents from %s" %(orig_dir, repaired_dir))
			rmtree(orig_dir)
			rename(repaired_dir, orig_dir)
			
			# report
			print("----------")
			if nb_missing + nb_uerrors > 0:
				print("DTD_REPAIR:errors: %i missing source files" % nb_missing)
				print("DTD_REPAIR:errors: %i unicode error files" % nb_uerrors)
			if nb_no_dtd_wiley + nb_no_dtd_other > 0:
				print("DTD_REPAIR:warn: %i wiley files with no dtd (normal)" % nb_no_dtd_wiley)
				print("DTD_REPAIR:warn: %i other files with no dtd (unknown)" % nb_no_dtd_other)
			print("----------")
	
	
	# GOLDTEI
	def pub2goldtei(self, pub2tei_dir=None, our_home=None, debug_lvl = 0):
		"""
		Appel d'une transformation XSLT 2.0 Pub2TEI
		
		actuellement via appel système à saxonb-xslt
		(renvoie 0 si tout est ok et 2 s'il n'y a eu ne serait-ce qu'une erreur)
		"""
		
		# dans 99% des cas c'est la même corpus_home
		# que celle à l'initialisation de l'objet
		if not our_home:
			our_home = self._home
		
		print("XSL: PUB2TEI CONVERSION (NATIVE XML TO GOLD)")
		if not pub2tei_dir:
			# chemin relatif au point de lancement
			p2t_path = path.join(THIS_SCRIPT_DIR, 'etc', 'Pub2TEI', 'Stylesheets','Publishers.xsl')
		else:
			p2t_path = path.join(pub2tei_dir,
								'Stylesheets','Publishers.xsl')
			if not path.exists(p2t_path):
				print("%s doit au moins contenir Stylesheets/Publishers.xsl" % pub2tei_dir)
				
		# vérification (est-ce que le fichier de sortie apparaît)
		nb_errors = 0
		
		# si dossier d'entrée
		if self.shelfs['XMLN']:
			# src
			xml_dirpath = self.shelf_path("XMLN")
			#tgt
			gtei_dirpath = self.shelf_path("GTEI")
			
			if debug_lvl > 0:
				print("XSL: src dir=%s" % xml_dirpath)
				print("XSL: tgt dir=%s" % gtei_dirpath)
			
			# mdkir dossier de sortie
			if not path.exists(gtei_dirpath):
				mkdir(gtei_dirpath)
			
			call_args = [
			"saxonb-xslt", 
			"-xsl:%s" % p2t_path,
			"-s:%s" % xml_dirpath,
			"-o:%s" % gtei_dirpath,
			# notre param pour les gold
			"teiBiblType=biblStruct",
			# éviter les simples quotes dans l'arg
			]
			
			if debug_lvl > 0:
				print("XSL: (debug) appel=%s" % call_args)
			
			try:
				# subprocess.call -----
				retval= call(call_args)
			except FileNotFoundError as fnfe:
				if search(r"saxonb-xslt", fnfe.strerror):
					print("XSL: les transformations pub2tei requièrent l'installation de saxonb-xslt (package libsaxonb-java)")
					return None
				else:
					raise
			
			# verification si les docs sont bien passés
			# et renommage en .tei.xml comme attendu par fileids()
			for fid in self.bnames:
				try:
					rename(path.join(gtei_dirpath, fid+'.xml'),
					        path.join(gtei_dirpath, fid+'.tei.xml'))
				except FileNotFoundError as fnfe:
					# £TODO alternative: keeping an error/ignore list with the object
					("XSL (skip) doc %s failed transformation" % fid)
					nb_errors += 1
			
			# on ne renvoie pas de valeur de retour, on signale juste le succès ou non
			if retval == 0:
				print("----------")
				print("XSL: %i successful transformations (all)" % self.size)
				print("----------")
			else:
				nb_ok = self.size - nb_errors
				print("----------")
				print("XSL: %i successful transformations" % nb_ok)
				print("XSL: %i failed transformations" % nb_errors)
				print("----------")


# utilisation autonome pour créer les dossiers basiques depuis une table
if __name__ == "__main__":
	"""
	Initialisation d'un corpus basique et remplissage de ses fulltexts
	  - on fournit une table de métadonnées infos.tab (chemin fs)
	
	Métadonnées, rangées dans <corpus_name>/meta/
	  - basenames.ls
	  - infos.tab
	
	Données: 3 formats, rangés dans <corpus_name>/data/
	  - .pdf, 
	  - .xml (natif) 
	  - et .tei.xml (pub2tei)
	
	Position dans le système de fichier:
		sous ./corpus_name
	"""
	
	parser = ArgumentParser(
		formatter_class=RawDescriptionHelpFormatter,
		description="""
    ---------------------------------------------
     ISTEX-RD corpus operator (tool and library)
    ---------------------------------------------

""",
		usage="""
------
  corpusdirs.py un_nom_de_corpus --from mes_docs.tsv""",
		epilog="""
Actions:
--------
   1) décharge PDF+XML natifs depuis l'API
   2) répare les DTD des XML natifs
   3) lance une conversion Pub2TEI

  => le tout dans des dossiers 
     bien rangés sous ./un_nom_de_corpus/

  --- © 2015 Inist-CNRS (ISTEX) romain.loth at inist.fr ---"""
		)
	
	# argument positionnel (obligatoire) : le nom du corpus
	parser.add_argument(
		'un_nom_de_corpus',
		type=str,
		help="nom du nouveau dossier corpus à créer"
	)
	
	#
	parser.add_argument('--from_table',
		metavar='mes_docs.tsv',
		help="""tableau en entrée (tout tsv avec en COL1 istex_id et en COL2 le nom du lot... (par ex: la sortie détaillée de l'échantilloneur sampler.py)""",
		type=str,
		default=None ,
		required=True,
		action='store')
	
	parser.add_argument('--debug',
		metavar='1',
		help="level of verbose/debug infos [default:0]",
		type=int,
		default=0 ,
		action='store')
	
	args = parser.parse_args(argv[1:])
	
	from_table = args.from_table
	debug = args.debug
	corpus_name = args.un_nom_de_corpus
	# =============================================
	
	if path.exists(corpus_name):
		print("ERR: le nom '%s' est déjà pris dans ce dossier" % corpus_name)
		exit(1)
	
	# (1/4) echantillon initial (juste la table) -------------------------
	if path.exists(from_table):
		fic = open(from_table)
		my_tab = [l.rstrip() for l in fic.readlines()]
		fic.close()
	else:
		print("ERR bako.make_set: je ne trouve pas la table '%s' pour initialiser le corpus" % from_table)
		exit(1)
	
	# (2/4) notre classe corpus ------------------------------------------
	
	# Corpus
	# initialisation
	#  - mode tab seul => fera un dossier meta/ et un data/ vide,
	#  - le corpus_type est mis en dur à 'gold' ce qui signale
	#    simplement qu'on ne change pas les étagères par défaut)
	cobj = Corpus(corpus_name, new_infos = my_tab, new_home  = '.', verbose = (debug>0))
	
	# (3/4) téléchargement des fulltexts ---------------------------------
	
	my_ids = cobj.cols['istex_id']
	my_basenames = cobj.bnames
	
	for the_shelf in ['PDF0', 'XMLN']:
		the_api_type = cobj.origin(the_shelf)
		the_ext      = cobj.filext(the_shelf)
		tgt_dir      = cobj.shelf_path(the_shelf)
		
		print("mkdir -p: %s" % tgt_dir)
		mkdir(tgt_dir)
		
		api.write_fulltexts_loop_interact(
			my_ids, my_basenames,
			tgt_dir   = tgt_dir,
			api_types = [the_api_type]
			)
		print("MAKE_SET: saved docs into CORPUS_HOME:%s" % cobj.name)
		if debug > 0:
			print("  (=> target dir:%s)" % tgt_dir)
		
		# NB: il doit y avoir la même extension dans cobj.filext(the_shelf) que chez l'API
		#  ou alors api.write_fulltexts doit autoriser à changer (renommer) les extensions
	
	cobj.assert_docs('PDF0')
	cobj.assert_docs('XMLN')
	
	# persistance du statut des 2 dossiers créés
	cobj.save_shelves_status()

	
	# (4/4) conversion tei (type gold biblStruct) ------------------------
	
	# copie en changeant les pointeurs dtd
	print("***DTD LINKING***")
	cobj.dtd_repair(debug_lvl = debug)
	
	print("***XML => TEI.XML CONVERSION***")
	
	# créera le dossier C-goldxmltei
	cobj.pub2goldtei(debug_lvl = debug)      # conversion
	
	cobj.assert_docs('GTEI')
	
	# persistence du statut du dossier créé
	cobj.save_shelves_status()
	
	# voilà !
	cobj.print_corpus_info()
	print("Corpus dirs successfully created in %s" % cobj.cdir)

