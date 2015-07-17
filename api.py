#! /usr/bin/python3
"""
Query the ISTEX API (ES: lucene q => json doc)
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.1"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

from json            import loads
from urllib.parse    import quote
from urllib.request  import urlopen
from urllib.error    import HTTPError

# globals
DEFAULT_API_CONF = {
	'host'  : 'api.istex.fr',
	'route' : 'document'
}

# private function
# ----------------
def _get(my_url):
	"""Get remote url *that contains a json* and parse it"""
	remote_file = urlopen(my_url)
	result_str = remote_file.read().decode('UTF-8')
	remote_file.close()
	json_values = loads(result_str)
	return json_values


# public functions
# ----------------
# £TODO: stockage disque sur fichier tempo si liste grande et champx nbx
def search(q, api_conf=DEFAULT_API_CONF, limit=None, outfields = ('title','host.issn','fulltext')):
	"""
	Query the API and get a (perhaps long) "hits" array of json metadata.
	
	args:
	-----
	   q    -- a lucene query
	                  ex: "quantum cat AND publicationDate:[1970 TO *]"
	
	optional kwargs:
	- - - - - - - - -
	   outfields   -- fieldNames list for the api to return for each hit 
	   limit       -- max returned hits threshold (= int)
	   api_conf    -- an inherited http config dict with these 2 keys:
	                    * api_conf['host']   <- default: "api.istex.fr"
	                    * api_conf['route']  <- default: "document"
	
	Output format is a parsed json with a total value and a hit list:
	{ 'hits': [ { 'id': '21B88F4EFBA46DC85E863709CA9824DEED7B7BFC',
				  'title': 'Recovering information borne by quanta that '
						   'crossed the black hole event horizon'},
				{ 'id': 'C095E6F0A43EBE3E98E2E6E17DD8775617636034',
				  'title': 'Holographic insights and puzzles'}],
	  'total': 2}
	"""
	
	# préparation requête
	url_encoded_lucene_query = quote(q)
	
	# construction de l'URL
	base_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&output=' + "fulltext,title"
	
	n_docs = count(q)
	# print('%s documents trouvés' % n_docs)
	
	# limitation éventuelle fournie par le switch --maxi
	if limit is not None:
		n_docs = limit
	
	# la liste des résultats à renvoyer
	all_hits = []
	
	# ensuite 2 cas de figure : 1 requête ou plusieurs
	if n_docs <= 5000:
		# requête simple
		my_url = base_url + '&size=%i' % n_docs
		json_values = _get(my_url)
		all_hits = json_values['hits']
	
	else:
		# requêtes paginées pour les tailles > 5000
		print("Collecting result hits... ")
		for k in range(0, n_docs, 5000):
			print("%i..." % k)
			my_url = base_url + '&size=5000' + "&from=%i" % k
			json_values = _get(my_url)
			all_hits += json_values['hits']
		
		# TODO stocker si > RAM/5
		
		# si on avait une limite par ex 7500 et qu'on est allés jusqu'à 10000
		all_hits = all_hits[0:n_docs]
	
	return(all_hits)


def count(q, api_conf=DEFAULT_API_CONF):
	"""
	Get total hits for a lucene query on ISTEX api.
	"""
	# préparation requête
	url_encoded_lucene_query = quote(q)
	
	# construction de l'URL
	count_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&size=1'
	
	# requête
	json_values = _get(count_url)
	
	
	return int(json_values['total'])
	

def terms_facet(facet_name, q="*", api_conf=DEFAULT_API_CONF):
	"""
	Get list of possible values/outcomes for a given field, with their counts (within the perimeter of the query q).
	
	output format {"facet_value_1": count_1, ...}
	"""
	# préparation requête
	url_encoded_lucene_query = quote(q)
	
	# construction de l'URL
	facet_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&facet=' + facet_name
	
	# requête
	json_values = _get(facet_url)
	key_counts = json_values['aggregations'][facet_name]['buckets']
	
	
	# simplification de la structure
	# [
	#  {'docCount': 8059500, 'key': 'en'},
	#  {'docCount': 1138473, 'key': 'de'}
	# ]
	# => sortie + compacte:
	#    {'en': 8059500, 'de': 1138473 }
	simple_dict = {}
	for record in key_counts:
		k = record['key']
		n = record['docCount']
		
		simple_dict[k] = n
	
	return simple_dict


########################################################################
if __name__ == '__main__':
	
	# test de requête simple
	q = input("test d'interrogation API ISTEX (entrez une requête Lucene):")
	
	print(search(q, limit=10))
	