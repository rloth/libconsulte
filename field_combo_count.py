#! /usr/bin/python3
"""
Pooling isolé de sampler.py, renvoie une combinaison d'aggrégations

(c'est-à-dire les décomptes par documents pour toute combinaison de critères)

Exemple de sortie:

{
 "f": {
  "corpusName:bmj AND publicationDate:[* TO 1979]": 368369,
  "corpusName:bmj AND publicationDate:[1980 TO 1999]": 163926,
  "corpusName:bmj AND publicationDate:[2000 TO *]": 172940,
  (...)
  "corpusName:oup AND publicationDate:[* TO 1979]": 734369,
  "corpusName:oup AND publicationDate:[1980 TO 1999]": 414020,
  "corpusName:oup AND publicationDate:[2000 TO *]": 287814,
  "corpusName:springer AND publicationDate:[* TO 1979]": 490971,
  "corpusName:springer AND publicationDate:[1980 TO 1999]": 547932,
  "corpusName:springer AND publicationDate:[2000 TO *]": 9,
  "corpusName:wiley AND publicationDate:[* TO 1979]": 1185039,
  "corpusName:wiley AND publicationDate:[1980 TO 1999]": 1621624,
  "corpusName:wiley AND publicationDate:[2000 TO *]": 1849095
 },
 "nd": 14675130,
 "nr": 14804223,
 "totd": 15968740
}
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.1"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

# imports standard
from sys       import argv, stderr
from re        import sub
from itertools import product
from json      import dumps
from argparse  import ArgumentParser


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


def my_parse_args(arglist=None):
	"""Arguments ligne de commande pour main()"""
	
	parser = ArgumentParser(
		description="--- Returns API doc counts for combined facets as json \"pools\" ---",
		usage="\n------\n  field_combo_count.py --crit luceneField1 luceneField2 ...",
		epilog="-- © 2014-2015 :: romain.loth at inist.fr :: Inist-CNRS (ISTEX) --"
		)
	
	parser.add_argument('-c', '--crit',
		dest="criteria_list",
		#~ metavar=('"corpusName"', '"publicationDate"'),
		metavar="",
		help="""API field(s) to count (exemple: corpusName publicationDate) (space-separated)""",
		nargs='+',
		required=True,
		action='store')
	
	parser.add_argument('-v', '--verbose',
		help="verbose switch",
		default=False,
		required=False,
		action='store_true')
	
	args = parser.parse_args(arglist)
	
	# --- checks and pre-propagation --------
	#  if known criteria ?
	flag_ok = True
	for field_name in args.criteria_list:
		if field_name not in field_value_lists.KNOWN_FIELDS:
			flag_ok = False
			print("Unknown field in -c args: '%s'" % field_name, 
			      file=stderr)
	
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
	
	if field_name in field_value_lists.TERMFACET_FIELDS_auto:
		# deuxième partie si un "sous.type"
		facet_name = sub('^[^.]+\.', '', field_name)
		return(api.terms_facet(facet_name).keys())
	
	elif field_name in field_value_lists.TERMFACET_FIELDS_local:
		# on a en stock 3 listes ad hoc
		if field_name == 'language':
			return(field_value_lists.LANG)
		elif field_name == 'genre':
			return(field_value_lists.GENRE)
		elif field_name == 'categories.wos':
			return(field_value_lists.SCAT)
		else:
			raise UnimplementedError()
	
	elif field_name in field_value_lists.RANGEFACET_FIELDS:
		applicable_bins = {}
		
		# recup des listes d'intervalles pertinentes
		# TODO faire une table de correspondance
		if field_name == 'publicationDate' or field_name == 'copyrightDate':
			applicable_bins = field_value_lists.DATE
		elif field_name == 'qualityIndicators.pdfCharCount':
			applicable_bins = field_value_lists.NBC
		luc_ranges = []
		
		# conversion couple(min max) en syntaxe lucene "[min TO max]"
		for interval in applicable_bins:
			a = str(interval[0])
			b = str(interval[1])
			luc_ranges.append('[' + a + ' TO ' + b + ']')
		return(luc_ranges)
	
	else:
		print ("ERROR: ?? the API doesn't allow a facet query on field '%s' (and I don't have a field_value_lists for this field either :-/ )" % field_name, file=stderr)
		exit(1)


def pooling(crit_fields, verbose=False):
	####### POOLING ########
	#
	N_reponses = 0
	N_workdocs = 0
	doc_grand_total = 0
	# dict of counts for each combo ((crit1:val_1a),(crit2:val_2a)...)
	abs_freqs = {}
	
	# ---------------------------------------------------------------
	# (1) PARTITIONING THE SEARCH SPACE IN POSSIBLE OUTCOMES --------
	print("Sending count queries for criteria pools...",file=stderr)
	## build all "field:values" pairs per criterion field
	## (list of list of strings: future lucene query chunks)
	all_possibilities = []
	
	# petit hommage à notre collègue Nourdine Combo !
	n_combos = 1
	
	for my_criterion in crit_fields:
		# print("CRIT",my_criterion)
		field_outcomes = facet_vals(my_criterion)
		# print("field_outcomes",field_outcomes)
		n_combos = n_combos * len(field_outcomes)
		# lucene query chunks
		all_possibilities.append(
			[my_criterion + ':' + val for val in field_outcomes]
		)
	
	# par ex: 2 critères vont donner 2 listes dans all_possibilities
	# [
	#  ['qualityIndicators.refBibsNative:T', 'qualityIndicators.refBibsNative:F'], 
	#
	#  ['corpusName:brill', 'corpusName:bmj', 'corpusName:wiley', 'corpusName:elsevier',
	#   'corpusName:ecco', 'corpusName:eebo', 'corpusName:springer', 'corpusName:nature', 
	#   'corpusName:oup', 'corpusName:journals']
	# ]
	
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
	
	# ---------------------------------------------------------------
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
		
		# print(freq)
		
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
	
	# resulting pool info in f + various totals
	return {'f':abs_freqs, 'nr':N_reponses, 'nd':N_workdocs, 'totd':doc_grand_total}

if __name__ == "__main__":
	# arguments cli
	args = my_parse_args(argv[1:])
	
	# run
	json = pooling(args.criteria_list, verbose=args.verbose)
	
	# sortie
	print(json)