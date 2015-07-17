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
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.1"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

# imports standard
from sys       import argv, stderr
from argparse  import ArgumentParser, RawDescriptionHelpFormatter

from re        import sub, search
from random    import shuffle
from itertools import product

# imports locaux
import api
import field_value_lists
# =<< target_language_values, target_scat_values, target_genre_values, target_date_ranges

# fields allowed as criteria, grouped according to the method we can use for value listing

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

# limit on maximum runs before returning a potentially undersized sample
MAX_RUNS = 5

# constante de lissage +k à chaque quota (aka lissage de Laplace)
LISSAGE = 0.5

# -------------------------


def my_parse_args():
	"""Preparation du hash des arguments ligne de commande pour main()"""
	
	parser = ArgumentParser(
		formatter_class=RawDescriptionHelpFormatter,
		description="A sampler to get a reprentative subset of ISTEX API.",
		usage="sampler.py -n 10000 [ -c corpusName publicationDate] [-q 'constraint query']",
		epilog="""
Default -c criteria are: "corpusName" "publicationDate" and "qualityIndicators.pdfVersion"

- © 2014-15 Inist-CNRS (ISTEX) romain.loth at inist.fr -
"""
		)
	
	parser.add_argument('-n',
		dest="sample_size",
		metavar='10000',
		help="the target sample size (mandatory integer)",
		type=int,
		required=True,
		action='store')
	
	parser.add_argument('-c',
		dest="criteria_list",
		metavar=('"corpusName"', '"publicationDate"'),
		help="list of representativity criteria (space separated) ==> Field(s) values will become quotas %% in the representativity estimate",
		nargs='+',
		default=('corpusName',
		         'publicationDate',
		         #~ 'qualityIndicators.pdfVersion',
		         ),
		required=False,
		action='store')
	
	parser.add_argument('-w',
		dest="with_constraint_query",
		metavar='"qualityIndicators.refBibsNative:true"',
		help="optional constraint on all members of the sample (lucene query)",
		type=str,
		required=False,
		action='store')
	
	parser.add_argument('-v', '--verbose',
		help="verbose switch",
		default=False,
		required=False,
		action='store_true')
	
	args = parser.parse_args(argv[1:])
	
	# --- checks ----------------------------
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
	
	if not flag_ok:
		exit(1)
	# ----------------------------------------
	
	return(args)


#~ def facet_count_value(criteria_dict):
	#~ """
	#~ Get counts for a combination of facets
	#~ """
	#~ 
	#~ # elements of the query we're building
	#~ temp_str_list = []
	#~ 
	#~ for facet in criteria_dict:
		#~ attr_val_str = "%s:%s" % (facet, criteria_dict[facet])
		#~ temp_str_list.append(attr_val_str)
	#~ 
	#~ my_query = " AND ".join(temp_str_list)
	#~ 
	#~ # run query => get the total
	#~ n_hits = api.count(my_query)
	#~ 
	#~ return(n_hits)


def facet_list_values(field_name):
	
	if field_name in TERMFACET_FIELDS_auto:
		# deuxième partie si un "sous.type"
		facet_name = sub('^[^.]+\.', '', field_name)
		return(api.terms_facet(facet_name))
	
	elif field_name in TERMFACET_FIELDS_local:
		# 3 listes ad hoc
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
		print ("The API doesn't allow 'terms' facet queries on field '%s'" % field_name, file=stderr)
		exit(1)


# sample() takes the same arguments as the module 

# Can be called several times with simplified criteria if impossible to
# get all sample_size in the 1st run (previous runs => index=got_id_idx)

def sample(size, crit_fields, constraint_query=None, index={}):
	
	# (1) PARTITIONING THE SEARCH SPACE IN POSSIBLE OUTCOMES -----------
	## build all "field:values" pairs per criterion field
	## (list of list of strings: future lucene query chunks)
	all_possibilities = []
	for my_criterion in crit_fields:
		field_outcomes = facet_list_values(my_criterion)
		all_possibilities.append(
			[my_criterion + ':' + val for val in field_outcomes]
		)
	
	## list combined possibilities (cartesian product of field_outcomes)
	# we're directly unpacking *args into itertool.product()
	# (and we get an iterator over tuples of combinable query chunks)
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
	
	
	# (2) getting total counts for each criteria -----------------------
	#
	# dict of counts for each combo
	abs_freqs = {}
	
	# number of counted answers
	# (/!\ one doc can give several hits if a criterion was multivalued)
	N_reponses = 0
	
	# do the counting for each combo
	for combi in combinations:
		query = " AND ".join(combi)
		
		# counting request
		freq = api.count(query)
		
		if args.verbose:
			print("pool:'% -30s': % 8i" %(query,freq),file=stderr)
		
		# storing and agregation
		N_reponses += freq
		abs_freqs[query] = freq
	
	# number of documents sending answers (hence normalizing constant N)
	N_workdocs = api.count(" AND ".join([k+":*" for k in crit_fields]))
	
	if args.verbose:
		print("--------- pool totals -----------", file=stderr)
		print("#answered hits :   % 12s" % N_reponses, file=stderr)
		print("#workdocs (N) :    % 12s" % N_workdocs, file=stderr)
		# for comparison: all_docs = N + api.count(q="NOT(criterion:*)")
		doc_grand_total = api.count(q='*')
		print("#all API docs fyi: % 12s" % doc_grand_total,file=stderr)
		print("---------------------------------", file=stderr)
	
	# (3) quota computation and availability checking ------------------
	#     
	# quota computation
	rel_freqs = {}
	for combi_query in abs_freqs:
		
		# CALCUL DU QUOTA INITIAL
		# expérimenter avec N_reponses au dénominateur ?
		quota = round(
		  size * abs_freqs[combi_query] / N_workdocs + LISSAGE
		)
		
		if quota != 0:
			rel_freqs[combi_query] = quota
	
	# fyi 3 lines to check if rounding surprise
	rndd_size = sum([quota for combi_query, quota in rel_freqs.items()])
	if args.verbose:
		print("Méthode des quotas taille sample:     % 9s" % rndd_size,
		      file=stderr)
	
	# récup AVEC CONTRAINTE et vérif total dispo (obtenu + dédoublonné)
	
	# got_ids_idx clés = ensemble d'ids , 
	#             valeurs = critères ayant mené au choix
	
	flag_has_previous_index = bool(index)
	my_warnings = []
	
	for combi_query in rel_freqs:
		
		# how many hits do we need?
		my_quota = rel_freqs[combi_query]
		if not flag_has_previous_index:
			# option A: direct quota allocation to search limit
			n_needed = my_quota
		else:
			# option B: limit larger than quota by retrieved amount
			#           (provides deduplication margin if 2nd run)
			#
			# /!\ wouldn't be necessary at all if we had none or rare
			#     duplicates, like with random result ranking)
			n_already_retrieved = len(
				[idi for idi,src_q in index.items() if search(combi_query, src_q)]
				)
			n_needed = my_quota + n_already_retrieved
		
		# adding constraints
		if constraint_query:
			my_query = '('+combi_query+') AND ('+constraint_query+')'
		else:
			my_query = combi_query
		
		# ----------------- api.search(...) ----------------------------
		json_hits = api.search(my_query, limit=n_needed, outfields='id')
		# --------------------------------------------------------------
		# £TODO 1
		# remplacer api.search() par une future fonction random_search
		# cf. elasticsearch guide: "random scoring" (=> puis supprimer
		# l'option B avec n_needed)
		
		# £TODO 2 tant que TODO 1 impossible, si limit = my_quota mais 
		#       qu'on est à un 2ème run, on risque au final d'avoir bcp
		#       moins de résultats, car les 1ers hits ont déjà été pris
		
		my_ids = [hit['id'] for hit in json_hits]
		
		my_n_answers = len(my_ids)
		
		my_n_got = 0
		
		# check unicity
		for idi in my_ids:
			if idi not in index:
				my_n_got += 1
				index[idi] = combi_query
			
			# needed ass long as n_needed != my_quota 
			# (should disappear as consequence of removing option B)
			if my_n_got == my_quota:
				break
		
		print ("%-70s: %i(%i)/%i" % (
					my_query[0:67]+"...", 
					my_n_got, 
					my_n_answers, 
					my_quota
				), file=stderr)
		
		if my_n_got < .85 * my_quota:
			my_warnings.append("%s sous-représentée : %i docs obtenus sur %i quota" % (combi_query, my_n_got, my_quota))
			
		#~ print("==========INDEX ITEMS===========")
		#~ print([kval for kval in index.items()])
		
	return(index, my_warnings)

if __name__ == "__main__":
	
	# cli arguments
	args = my_parse_args()
	
	# initial sampler run
	got_ids_idx, warnings = sample(
								args.sample_size,
								args.criteria_list,
								constraint_query = args.with_constraint_query
							)
	# ne kadar?
	n_ids = len(got_ids_idx)
	print('-'*27 + " initial result : %i docs " % n_ids + '-'*27,
		  file=stderr)
	
	# --------- a posteriori corrections -------------
	#
	# the initial quotas can take neither the "with_constraint arg"
	# nor "multiple choice fields" into account (unless use N_reponse?)
	
	# for that reason at this point in the process we may have more or
	# less than the requested sample_size
	
	# IF not enough => new sample_run with lighter criteria
	if n_ids < args.sample_size:
		
		actual_criteria = args.criteria_list
		run_counter = 1
		
		# re-run
		while (n_ids < args.sample_size and run_counter < MAX_RUNS):
			if len(actual_criteria) > 1:
				# simplify criteria by removing the last one
				new_criteria = actual_criteria[0:-1]
			else:
				new_criteria = actual_criteria
			
			remainder = args.sample_size - n_ids
			previous_ids = got_ids_idx
			got_ids_idx, warnings = sample(
									 remainder,
									 new_criteria,
									 constraint_query = args.with_constraint_query,
									 index = previous_ids
									)
			# recount
			n_ids = len(got_ids_idx)
			run_counter += 1
			      #(corpusName:elsevier) AND (qualityIndicators.pdfWordCount:[300 TO *...: 65(2175)/65
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
		print("...sacrificing %i random docs... ok" % nd ,file=stderr)
	
	# last recount
	n_ids = len(got_ids_idx)
	print('-'*29 +" final result: %i docs "%n_ids+'-'*29, file=stderr)
	
	# sortie
	for did in got_ids_idx:
		info = got_ids_idx[did]
		print ("%s\t%s" % (did, info))
