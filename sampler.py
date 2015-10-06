#! /usr/bin/python3
"""
Prepare and download a representative sample from the ISTEX API.

The script uses lucene "attribute:value" pairs to select subsets of documents :
  - in a given perimeter: pick docs that match a given CONSTRAINT
  - with representativity: pick docs that follow same distribution as pool over some CRITERIA

Representativity via -c
========================
We need a distribution with volumes proportional to the pool on several criteria.
	Exemple *criteria* list:
		- criterion 1 = WOS discipline
		- criterion 2 = pdf version
	=> proportionality will be benchmarked on those criteria only

Perimeter via -w
=================
Another independant "attribute:value" group will define a CONSTRAINT on the sample.
	Exemple *constraints*:
		"qualityIndicators.refBibsNative:true"
		"qualityIndicators.pdfCharCount:[500 TO *]"

Assumes LC_ALL (aka sys.stdout.encoding) is 'UTF-8'
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.3"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

# imports standard
from sys       import argv, stderr
from re        import sub, search, escape
from random    import shuffle
from itertools import product
from datetime  import datetime
from os        import path, mkdir, getcwd
from json      import dump, load
from argparse  import ArgumentParser, RawTextHelpFormatter


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
		print("""ERR: Les modules 'api.py' et 'field_value_lists.py' doivent être
		 placés à côté du script sampler.py ou dans un dossier du PYTHONPATH, pour sa bonne execution...""", file=stderr)
		exit(1)

# utile pour le cache
HOME=path.dirname(path.realpath(__file__))

# Globals
# --------
# limit on maximum runs before returning a potentially undersized sample
MAX_RUNS = 5
# paramètre de lissage +k à chaque quota (aka lissage de Laplace)
LISSAGE = 0.2
# list of IDs to exclude from the sample result
FORBIDDEN_IDS = []


# fields allowed as criteria
# (grouped according to the method we use for value listing)

# auto value-listing via facet query
TERMFACET_FIELDS_auto = [
	'corpusName', 
	'qualityIndicators.pdfVersion', 
	'qualityIndicators.refBibsNative'
	]

# value-listing provided locally (stored into field_value_lists.py)
TERMFACET_FIELDS_local = [
	'language',
	'genre',
	'categories.wos'
	]

# binned listing via date ranges (also in field_value_lists.py)
RANGEFACET_FIELDS = [
	'publicationDate',
	'copyrightDate'
	]

# ----------------------------------------------------------------------
# CONSTANT mapping standard fields
# (key: API Name, val: local name <= the value is actually not used
# 
# the keys are used in the API queries
# the vals are unused but could be used in the 'tab' output mode as standard column names (£TODO)
STD_MAP = {
	'id'              : 'istex_id',  # 40 caractères [0-9A-F]
	'doi'             : 'doi',
	'corpusName'      : 'istex_lot', # que les trois premières lettres
	'publicationDate' : 'pub_year',  # le premier match à /(1\d|20)\d\d/
	'author.name'     : 'authors_',
	'genre'           : 'genres_',   # avec recodage ?
	'title'           : 'title',
	'language'        : 'lang',      # avec recodage
	'categories.wos'  : 'cats_',     # à étendre
	'serie.issn'      : 'in_issn',   # en distri. compl. avec host.issn
	'host.issn'       : 'in_issn',
	#'volume'          : 'in_vol',   # todo
	#'firstPage'       : 'in_fpg'    # todo
	'qualityIndicators.pdfVersion' : 'pdfver',
	'qualityIndicators.pdfWordCount' : 'pdfwc',
}

# [+ colonnes calculées]
# ----------------------
#> src_query
#X pages_3bins    # todo
#X periode        # todo


# ----------------------------------------------------------------------
def my_parse_args(arglist=None):
	"""Preparation du hash des arguments ligne de commande pour main()"""
	global FORBIDDEN_IDS
	
	parser = ArgumentParser(
		formatter_class=UnindentHelp,
		description="""
	------------------------------------------------------------
	 A sampler to get a representative subset of ISTEX API docs
	------------------------------------------------------------""",
		usage="\n------\n  sampler.py -n 10000 [--with 'lucene query'] [--crit luceneField1 luceneField2 ...]",
		epilog="""--------------
/!\\ known bug: until API provides random ranking function, we are going
               to create *identical* samples for 2 runs with same params
               (instead of creating 2 different random ones...)

© 2014-2015 :: romain.loth at inist.fr :: Inist-CNRS (ISTEX)
"""
		)
	
	parser.add_argument('-n',
		dest="sample_size",
		metavar='10000',
		help="the target sample size (mandatory integer)",
		type=int,
		required=True,
		action='store')
	
	parser.add_argument('-c', '--crit',
		dest="criteria_list",
		#~ metavar=('"corpusName"', '"publicationDate"'),
		metavar="",
		help="""API field(s) used as \"representativity quota\" criterion
				(default: corpusName publicationDate) (space-separated)""",
		nargs='+',
		default=('corpusName',
		         'publicationDate',
		         #~ 'qualityIndicators.pdfVersion',
		         ),
		required=False,
		action='store')
	
	parser.add_argument('-w', "--with",
		dest="with_constraint_query",
		metavar="'query'",
		help="""
		lucene query to express constraints on all the sample
		(example: \"qualityIndicators.refBibsNative:true\")""",
		type=str,
		required=False,
		action='store')
	
	parser.add_argument('-x', "--exclude-list",
		dest="exclude_list_path",
		metavar="",
		help="optional list of IDs to exclude from sampling",
		type=str,
		required=False,
		action='store')
	
	parser.add_argument('-s', '--smooth',
		dest="smoothing_init",
		metavar='0.5',
		help="""
		a uniform bonus of docs for all classes (default: 0.1)
		(higher smoothing will favour small quota groups)""",
		type=float,
		required=False,
		action='store')
	
	parser.add_argument('-o', '--outmode',
		dest="out_type",
		metavar="ids",
		help="""
		choice of the output form: 'ids', 'tab' or 'docs'
		  ids:  a simple list of API ids
		        ex: sampler.py -o ids -n 20 > my_ids.txt
		
		  tab:  a more detailed tabular output
		        (info columns starting with API ids + source query)
		        ex: sampler.py -o tab -n 20 > my_tab.tsv
		
		  docs: downloads all docs (tei + pdf) in a new
		        directory named 'echantillon_<timestamp>'
		        ex: sampler.py -o docs -n 20""",
		choices=['ids', 'tab', 'docs'],
		type=str,
		default='ids',
		required=False,
		action='store')
	
	
	parser.add_argument('-v', '--verbose',
		help="verbose switch",
		default=False,
		required=False,
		action='store_true')
	
	args = parser.parse_args(arglist)
	
	# --- checks and pre-propagation --------
	#  if known criteria ?
	known_fields_list = TERMFACET_FIELDS_auto + TERMFACET_FIELDS_local + RANGEFACET_FIELDS
	flag_ok = True
	for field_name in args.criteria_list:
		if field_name not in known_fields_list:
			flag_ok = False
			print("Unknown field in -c args: '%s'" % field_name, 
			      file=stderr)
		# TODO vérifier si ça a évolué
		elif field_name == "genre":
			print("/!\ Experimental field: 'genre' (inventory not yet harmonized)", file=stderr)

	# do we need to forbid an ID list ?
	if args.exclude_list_path:
		fh = open(args.exclude_list_path, 'r')
		i = 0
		for line in fh:
			i += 1
			if search("^[0-9A-F]{40}$", line):
				FORBIDDEN_IDS.append(line.rstrip())
			else:
				raise TypeError("line %i is not a valid ISTEX ID" % i)
	
	
	if not flag_ok:
		exit(1)
	# ----------------------------------------
	
	return(args)


def facet_vals(field_name):
	"""
	For each field, returns the list of possible outcomes
	
	ex: > facet_vals('corpusName')
	    > ['elsevier','wiley', 'nature', 'sage', ...]
	"""
	
	if field_name in TERMFACET_FIELDS_auto:
		# deuxième partie si un "sous.type"
		facet_name = sub('^[^.]+\.', '', field_name)
		return(api.terms_facet(facet_name))
	
	elif field_name in TERMFACET_FIELDS_local:
		# on a en stock 3 listes ad hoc
		if field_name == 'language':
			return(field_value_lists.LANG)
		elif field_name == 'genre':
			return(field_value_lists.GENRE)
		elif field_name == 'categories.wos':
			return(field_value_lists.SCAT)
		else:
			raise UnimplementedError()
	
	elif field_name in RANGEFACET_FIELDS:
		luc_ranges = []
		for interval in field_value_lists.DATE:
			a = str(interval[0])
			b = str(interval[1])
			luc_ranges.append('[' + a + ' TO ' + b + ']')
		return(luc_ranges)
	
	else:
		print ("ERROR: ?? the API doesn't allow a facet query on field '%s' (and I don't have a field_value_lists for this field either :-/ )" % field_name, file=stderr)
		exit(1)


def year_to_range(year):
	"""
	ex 1968 => "[1950-1969]"
	"""
	min_year = 0
	max_year = 2100
	
	flag_convertible = True
	int_year = None
	
	if isinstance(year,int):
		int_year = year
	else:
		# on va travailler sur les 4 
		# premiers chars de la chaîne
		year = str(year)
		if len(year) > 4:
			year = year[0:4]
		try:
			int_year = int(year)
		except ValueError:
			flag_convertible = False
	
	# décisions
	if not flag_convertible:
		return "UNKOWN_PERIOD"
	elif int_year > max_year or int_year < min_year:
		return "YEAR_OUT_OF_RANGE"
	else:
		my_interval = None
		for interval in field_value_lists.DATE:
			my_interval = interval
			# on monte en ordre chrono
			# => on ne teste que la fin
			fin = interval[1]
			# cas limite
			if interval[1] == "*":
				fin = max_year
			# comparaison dans tous les cas
			fin_int = int(fin)
			if int_year < fin_int:
				# on a le bon !
				break
		# conversion intervalle => string
		return '[' + str(my_interval[0]) + ' TO ' + str(my_interval[1]) + ']'





# sample() takes the same arguments as the module 

# Can be called several times with simplified criteria if impossible to
# get all sample_size in the 1st run (previous runs => index=got_id_idx)

def sample(size, crit_fields, constraint_query=None, index=None, 
           verbose=False, run_count = 0):
	global LOG
	global LISSAGE
	global FORBIDDEN_IDS
	
	# allows to set default to None instead of tricky-scope mutable {}
	if not index:
		index = {}
		flag_previous_index = False
	else:
		flag_previous_index = True
	
	
	####### POOLING ########
	#
	N_reponses = 0
	N_workdocs = 0
	doc_grand_total = 0
	# dict of counts for each combo ((crit1:val_1a),(crit2:val_2a)...)
	abs_freqs = {}
	
	
	# instead do steps (1) (2) maybe we have cached the pools ?
	# (always same counts for given criteria) => cache to json
	cache_filename = pool_cache_path(crit_fields)
	print('...checking cache for %s' % cache_filename,file=stderr)
	
	if path.exists(cache_filename):
		cache = open(cache_filename, 'r')
		pool_info = load(cache)
		abs_freqs       = pool_info['f']
		N_reponses      = pool_info['nr']
		N_workdocs      = pool_info['nd']
		doc_grand_total = pool_info['totd']
		print('...ok cache (%i workdocs)' % N_workdocs,file=stderr)
	else:
		print('...no cache found',file=stderr)
		
		# (1) PARTITIONING THE SEARCH SPACE IN POSSIBLE OUTCOMES --------
		print("Sending count queries for criteria pools...",file=stderr)
		## build all "field:values" pairs per criterion field
		## (list of list of strings: future lucene query chunks)
		all_possibilities = []
		n_combos = 1
		for my_criterion in crit_fields:
			field_outcomes = facet_vals(my_criterion)
			n_combos = n_combos * len(field_outcomes)
			# lucene query chunks
			all_possibilities.append(
				[my_criterion + ':' + val for val in field_outcomes]
			)
		
		
		## list combos (cartesian product of field_outcomes)
		# we're directly unpacking *args into itertool.product()
		# (=> we get an iterator over tuples of combinable query chunks)
		combinations = product(*all_possibilities)
		
		
		# example for -c corpusName, publicationDate
		#	[
		#	('corpusName:ecco', 'publicationDate:[* TO 1959]'),
		#	('corpusName:ecco', 'publicationDate:[1960 TO 1999]'),
		#	('corpusName:ecco', 'publicationDate:[2000 TO *]'),
		#	('corpusName:elsevier', 'publicationDate:[* TO 1959]'),
		#	('corpusName:elsevier', 'publicationDate:[1960 TO 1999]'),
		#	('corpusName:elsevier', 'publicationDate:[2000 TO *]'),
		#	(...)
		#	]
		
		# (2) getting total counts for each criteria --------------------
		
		# number of counted answers
		#  (1 doc can give several hits if a criterion was multivalued)
		N_reponses = 0
		
		# do the counting for each combo
		for i, combi in enumerate(sorted(combinations)):
			if i % 100 == 0:
				print("pool %i/%i" % (i,n_combos), file=stderr)
			
			query = " AND ".join(combi)
			
			# counting requests ++++
			freq = api.count(query)
			
			if verbose:
				print("pool:'% -30s': % 8i" %(query,freq),file=stderr)
			
			# storing and agregation
			N_reponses += freq
			abs_freqs[query] = freq
		
		# number of documents sending answers (hence normalizing constant N)
		N_workdocs = api.count(" AND ".join([k+":*" for k in crit_fields]))
		
		if verbose:
			print("--------- pool totals -----------", file=stderr)
			print("#answered hits :   % 12s" % N_reponses, file=stderr)
			print("#workdocs (N) :    % 12s" % N_workdocs, file=stderr)
			# for comparison: all_docs = N + api.count(q="NOT(criterion:*)")
			doc_grand_total = api.count(q='*')
			print("#all API docs fyi: % 12s" % doc_grand_total,file=stderr)
			print("---------------------------------", file=stderr)
		
		
		# cache write
		cache = open(cache_filename, 'w')
		pool_info = {'f':abs_freqs, 'nr':N_reponses, 
		            'nd':N_workdocs, 'totd':doc_grand_total}
		# json.dump
		dump(pool_info, cache, indent=1)
		cache.close()
	
	
	######### QUOTA ########
	#
	# (3) quota computation and availability checking ------------------
	# quota computation
	rel_freqs = {}
	for combi_query in abs_freqs:
		
		# expérimenter avec N_reponses au dénominateur ?
		quota = round(
		  size * abs_freqs[combi_query] / N_workdocs + LISSAGE
		)
		
		if quota != 0:
			rel_freqs[combi_query] = quota
	
	# fyi 3 lines to check if rounding surprise
	rndd_size = sum([quota for combi_query, quota in rel_freqs.items()])
	if verbose:
		print("Méthode des quotas taille avec arrondis:     % 9s" % rndd_size,
		      file=stderr)
	
	# récup AVEC CONTRAINTE et vérif total dispo (obtenu + dédoublonné)
	
	# got_ids_idx clés = ensemble d'ids , 
	#             valeurs = critères ayant mené au choix
	
	print("Retrieving new sample chunks per pool quota...", file=stderr)
	
	for combi_query in sorted(rel_freqs.keys()):
		
		# how many hits do we need?
		my_quota = rel_freqs[combi_query]
		if not flag_previous_index and not FORBIDDEN_IDS:
			# option A: direct quota allocation to search limit
			n_needed = my_quota
		else:
			# option B: limit larger than quota by retrieved amount
			#           (provides deduplication margin if 2nd run)
			#
			# /!\ wouldn't be necessary at all if we had none or rare
			#     duplicates, like with random result ranking)
			
			# supplément 1: items to skip
			n_already_retrieved = len(
				# lookup retrieved
				[idi for idi,metad in index.items()
					if search(escape(combi_query), metad['_q'])]
				)
			
			# supplément 2: prorata de FORBIDDEN_IDS
			suppl = round(len(FORBIDDEN_IDS) * my_quota / size)
			n_already_retrieved += suppl
			n_needed = my_quota + n_already_retrieved
		
		# adding constraints
		if constraint_query:
			my_query = '('+combi_query+') AND ('+constraint_query+')'
		else:
			my_query = combi_query
		
		# ----------------- api.search(...) ----------------------------
		json_hits = api.search(my_query, 
		                       limit=n_needed,
		                       outfields=STD_MAP.keys())
	        # outfields=('id','author.name','title','publicationDate','corpusName')

		# --------------------------------------------------------------
		
		# NB: 'id' field would be enough for sampling itself, but we get
		#     more metadatas to be able to provide an info table or to
		#     create a human-readable filename
		
		# £TODO 1
		# remplacer api.search() par une future fonction random_search
		# cf. elasticsearch guide: "random scoring" (=> puis supprimer
		# l'option B avec n_needed)
		
		my_n_answers = len(json_hits)
		
		my_n_got = 0
		
		# for debug
		# print("HITS:",json_hits, file=stderr)
		
		
		# check unicity
		for hit in json_hits:
			idi = hit['id']
			
			if idi not in index and idi not in FORBIDDEN_IDS:
				# print(hit)
				# exit()
				my_n_got += 1
				# main index
				index[idi] = {
					'_q': combi_query,
					'co': hit['corpusName'][0:3]  # trigramme eg 'els'
					}
				# store info
				# £TODO: check conventions for null values
				# £TODO: ajouter tout ça dans STD_MAP
				if 'publicationDate' in hit and len(hit['publicationDate']):
					index[idi]['yr'] = hit['publicationDate'][0:4]
				else:
					index[idi]['yr'] = 'XXXX'
				
				if 'title' in hit and len(hit['title']):
					index[idi]['ti'] = hit['title']
				else:
					index[idi]['ti'] = "UNTITLED"
				
				if 'author' in hit and len(hit['author'][0]['name']):
					first_auth = hit['author'][0]['name']
					his_lastname = first_auth.split()[-1]
					index[idi]['au'] = his_lastname
				else:
					index[idi]['au'] = "UNKNOWN"
				
				if 'language' in hit and len(hit['language']):
					index[idi]['lg'] = hit['language'][0]
				else:
					index[idi]['lg'] = "UNKOWN_LANG"
				
				if 'genre' in hit and len(hit['genre']):
					index[idi]['typ'] = hit['genre'][0]
				else:
					index[idi]['typ'] = "UNKOWN_GENRE"
				
				if 'categories' in hit and len(hit['categories']) and 'wos' in hit['categories'] and len(hit['categories']['wos']):
					index[idi]['cat'] = "/".join(hit['categories']['wos'])
				else:
					index[idi]['cat'] = "UNKOWN_SCI_CAT"
				
				if 'qualityIndicators' in hit and 'pdfVersion' in hit['qualityIndicators']:
					index[idi]['ver'] = hit['qualityIndicators']['pdfVersion']
				else:
					index[idi]['ver'] = "UNKNOWN_PDFVER"
				
				if 'qualityIndicators' in hit and 'pdfWordCount' in hit['qualityIndicators']:
					index[idi]['wcp'] = hit['qualityIndicators']['pdfWordCount']
				else:
					index[idi]['wcp'] = "UNKNOWN_PDFWORDCOUNT"
				
			# recheck limit: needed as long as n_needed != my_quota 
			# (should disappear as consequence of removing option B)
			if my_n_got == my_quota:
				break
		
		print ("%-70s: %i(%i)/%i" % (
					my_query[0:67]+"...", 
					my_n_got, 
					my_n_answers, 
					my_quota
				), file=stderr)
		
		# if within whole sample_size scope, we may observe unmeatable
		# representativity criteria (marked 'LESS' and checked for RLAX)
		if run_count == 0 and my_n_got < (.85 * (my_quota - LISSAGE)):
			my_s = "" if my_n_got == 1 else "s"
			LOG.append("LESS: catégorie '%s' sous-représentée pour contrainte \"%s\" : %i doc%s obtenu%s sur %i quota" % (combi_query, constraint_query, my_n_got, my_s, my_s, my_quota))
			
		# print("==========my_corpus ITEMS===========")
		# print([kval for kval in my_corpus.items()])
		
	return(index)


def pool_cache_path(criteria_list):
	"""pool_cache filename: sorted-criteria-of-the-set.pool.json"""
	global HOME
	cset_pool_path = path.join(HOME, 'pool_cache',
			'-'.join(sorted(criteria_list, reverse=True))+'.pool.json')
	
	# relative path ./pool_cache/.
	return cset_pool_path


class UnindentHelp(RawTextHelpFormatter):
	# indents help args, 
	# doesn't do anything to 'usage' or 'epilog' descriptions
	def _split_lines(self, text, width):
		text = sub(r"\t", "", text)
		text = sub(r"^\n+", "", text) + "\n\n"
		return text.splitlines()


########################################################################
# todo mettre à part dans une lib
def std_filename(istex_id, info_dict):
	'''
	Creates a human readable file name from work records.
	Expected dict keys are 'co' (corpus),'au','yr','ti'
	'''
	ok = {}
	for k in info_dict:
		ok[k] = safe_str(info_dict[k])
	
	# shorten title
	ok['ti'] = ok['ti'][0:30]
	
	return '-'.join([istex_id, ok['co'], ok['au'], ok['yr'], ok['ti']])


# todo mettre à part dans une lib
def safe_str(a_string=""):
	return sub("[^A-Za-z0-9àäçéèïîøöôüùαβγ]+","_",a_string)

########################################################################

def full_run(arglist=None):
	global LOG
	global LISSAGE
	# output lines for direct use or print to STDOUT if __main__
	output_array = []
	
	# cli arguments
	args = my_parse_args(arglist)
	
	# do we need to change smoothing ?
	if args.smoothing_init and float(args.smoothing_init) > 0:
		print("Setting initial smoothing to %.2f" % args.smoothing_init, file=stderr)
		# global var change in main
		LISSAGE = args.smoothing_init
	
	# event log lines
	LOG = ['INIT: sampling %i' % args.sample_size]
	LOG.append('CRIT: fields(%s)' % ", ".join(args.criteria_list))
	if args.with_constraint_query:
		LOG.append('WITH: constraint query "%s"' % args.with_constraint_query)
	
	run_counter = 0
	
	# initial sampler run
	got_ids_idx = sample(
						args.sample_size,
						args.criteria_list,
						constraint_query = args.with_constraint_query,
						verbose = args.verbose,
						run_count = run_counter
						)
	run_counter += 1
	
	# how much is there?
	n_ids = len(got_ids_idx)
	
	# info
	print('-'*27 + " initial result : %i docs " % n_ids + '-'*27,
		  file=stderr)
	
	LOG.append("XGOT: picked %i" % n_ids)
	
	# check combopools status
	insufficient_pool_flag = False
	for sig in LOG:
		if search("^LESS:", sig):
			insufficient_pool_flag = True
			break
	
	# --------- a posteriori corrections -------------
	#
	# the initial quotas can take neither the "with_constraint arg"
	# nor "multiple choice fields" into account (unless use N_reponse?)
	
	# for that reason at this point in the process we may have more or
	# less than the requested sample_size
	
	# IF not enough => new sample run with lighter criteria
	if n_ids < args.sample_size:
		
		actual_criteria = args.criteria_list
		
		# keep trying...
		while (n_ids < args.sample_size and run_counter < MAX_RUNS):
			
			# => over "delta" (missing docs)
			remainder = args.sample_size - n_ids
			LOG.append("REDO: re-pioche sur %i docs" % remainder)
			
			# => with more help to small categories
			LISSAGE += 0.2
			LOG.append("SMOO: smoothing up to %.02f" % LISSAGE)
			
			# => and with less criteria if necessary
			# (if criteria pool insufficient under some constraints, we
			#  do need to relax at least one criterion, but which one?)
			if len(actual_criteria) > 1 and insufficient_pool_flag:
				# simplify criteria by removing the last one
				new_criteria = actual_criteria[0:-1]
				LOG.append("RLAX: abandon équilibrage champ '%s'" %
								actual_criteria[-1])
				
				# reset flag (£TODO recalculate after run ?)
				insufficient_pool_flag = False
			else:
				new_criteria = actual_criteria
			
			# -------- RE-RUN ---------
			previous_ids = got_ids_idx
			got_ids_idx = sample(
						remainder,
						new_criteria,
						constraint_query = args.with_constraint_query,
						index = previous_ids,
						verbose = args.verbose
						)
			
			# recount
			apport = len(got_ids_idx) - n_ids
			
			# update
			n_ids += apport
			run_counter += 1
			
			# warn
			LOG.append("XGOT: picked %i" % apport)
			print('-'*22 + " resultat après run %i: %i documents " 
			    % (run_counter, n_ids) + '-'*22, file=stderr)
	
	
	# IF overflow => random pruning
	if n_ids > args.sample_size:
		deck = [did for did in got_ids_idx.keys()]
		# random removal of excess documents
		shuffle(deck)
		nd = n_ids - args.sample_size
		sacrificed = deck[0:nd]
		for did in sacrificed:
			del got_ids_idx[did]
		LOG.append("XDEL: sacrificing %i random docs" % nd)
	
	# last recount
	n_ids = len(got_ids_idx)
	print('-'*29 +" final result: %i docs "%n_ids+'-'*29, file=stderr)
	
	# -------------- OUTPUT --------------------------------------------
	
	# ***(ids)***
	if args.out_type == 'ids':
		for did, info in sorted(got_ids_idx.items(), key=lambda x: x[1]['_q']):
			output_array.append("%s" % did)
	
	# ***(tab)***
	elif args.out_type == 'tab':
		# header line
		# £TODO STD_MAP
		output_array.append("\t".join(['istex_id', 'corpus', 'pub_year', 'pub_period', 'pdfver', 'pdfwc',
						 'author_1','lang','doctype_1','cat_sci', 'title']))
		# contents
		for did, info in sorted(got_ids_idx.items(), key=lambda x: x[1]['_q']):
			# provenance: sample() => boucle par hits (l.500 ++)
			# print("INFO----------",info, file=stderr)
			# exit()
			
			period = year_to_range(info['yr'])
			
			
			output_array.append("\t".join([ did,
			                                info['co'],
			                                info['yr'],
			                                period,
			                                info['ver'],
			                                str(info['wcp']),
			                                info['au'],
			                                info['lg'],
			                                info['typ'],
			                                info['cat'],
			                                info['ti'],
			                                #~ info['_q']
			                                ]
			                              )
			             )
	
	# ***(docs)***
	# no output lines but writes a dir
	elif args.out_type == 'docs':
		my_dir = path.join(getcwd(),my_name)
		mkdir(my_dir)
		
		# two "parallel" lists
		ids = list(got_ids_idx.keys())
		basenames = [std_filename(one_id, got_ids_idx[one_id]) for one_id in ids]
		
		# loop with interactive authentification prompt if needed
		api.write_fulltexts_loop_interact(
			ids, basenames,
			tgt_dir=my_dir,
			api_types=['metadata/xml',
					   'fulltext/pdf']
		)
		
		LOG.append("SAVE: saved docs in %s/" % my_dir)
	
	
	return (output_array, LOG)

########################################################################

if __name__ == "__main__":
	# stamp
	timestamp = datetime.now().strftime("%Y-%m-%d_%Hh%M")
	my_name = "echantillon_%s" % timestamp
	
	# run
	(stdoutput, LOG) = full_run(arglist = argv[1:])
	
	# output lines
	for line in stdoutput:
		print(line)
	
	# separate logging lines
	logfile = open(my_name+'.log', 'w')
	for lline in LOG:
		print(lline, file=logfile)
	logfile.close()
