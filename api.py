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
from urllib.request  import urlopen, HTTPBasicAuthHandler, build_opener, install_opener
from urllib.error    import URLError

from os import path
from sys import stderr

# globals
DEFAULT_API_CONF = {
	'host'  : 'api.istex.fr',
	'route' : 'document'
}

class AuthWarning(Exception):
	def __init__(self, msg):
		self.msg = msg
	def __str__(self):
		return repr(self.msg)

# private function
# ----------------
def _get(my_url):
	"""Get remote url *that contains a json* and parse it"""
	
	#~ print("> api._get:%s" % my_url, file=stderr)
	
	try:
		remote_file = urlopen(my_url)
		
	except URLError as url_e:
		# signale 401 Unauthorized ou 404 etc
		print("api: HTTP ERR (%s) sur '%s'" % 
			(url_e.reason, my_url), file=stderr)
		# Plus d'infos: serveur, Content-Type, WWW-Authenticate..
		# print ("ERR.info(): \n %s" % url_e.info(), file=stderr)
		exit(1)
	try:
		response = remote_file.read()
	except httplib.IncompleteRead as ir_e:
		response = ir_e.partial
		print("WARN: IncompleteRead '%s' but 'partial' content has page" 
				% my_url, file=stderr)
	remote_file.close()
	result_str = response.decode('UTF-8')
	json_values = loads(result_str)
	return json_values

def _sget(my_url, mon_user=None, mon_pass=None):
	"""
	Get remote auth-protected url *that contains a file* and pass it
	For instance when retrieving fulltext from ISTEX API
	"""
	
	# print ("REGARD:", mon_user, mon_pass)
	
	auth_handler = HTTPBasicAuthHandler()
	auth_handler.add_password(
			realm  = 'Authentification sur api.istex.fr',
			uri    = 'https://api.istex.fr',
			user   = mon_user,
			passwd = mon_pass)
	install_opener(build_opener(auth_handler))
	
	# contact
	try:
		remote_file = urlopen(my_url)
		
	except URLError as url_e:
		if url_e.getcode() == 401:
			raise AuthWarning("need_auth")
		else:
			# 404 à gérer sans quitter pour les fulltexts
			print("api: HTTP ERR no %i (%s) sur '%s'" % 
				(url_e.getcode(),url_e.msg, my_url), file=stderr)
			print ("ERR.info(): \n %s" % url_e.info(), file=stderr)
			# exit(1)
	
	# lecture
	contents = remote_file.read()
	remote_file.close()
	
	return contents


# public functions
# ----------------
# £TODO: stockage disque sur fichier tempo si liste grande et champx nbx
def search(q, api_conf=DEFAULT_API_CONF, limit=None, outfields=('title','host.issn','fulltext')):
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
	base_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&output=' + ",".join(outfields)
	
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
		print("Collecting result hits... ", file=stderr)
		for k in range(0, n_docs, 5000):
			print("%i..." % k, file=stderr)
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
	
	
def write_fulltexts(api_did, api_conf=DEFAULT_API_CONF, tgt_dir='.', login=None, passw=None, base_name=None):
	"""
	Get TEI, PDF and ZIP fulltexts for a given ISTEX document.
	"""
	# préparation requête
	fulltext_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + api_did + '/fulltext/'
	
	# available_filetypes = ['pdf', 'tei', 'zip']
	available_filetypes = ['pdf', 'tei']
	
	# default name is just the ID
	if not base_name:
		base_name = api_did
	
	for filetype in available_filetypes:
		response = _sget(fulltext_url + filetype, 
							mon_user=login, mon_pass=passw)
		tgt_path = path.join(tgt_dir, base_name+'.'+filetype)
		fh = open(tgt_path, 'wb')
		fh.write(response)
		fh.close()
	return None

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
	
	# test de récupération PDF (avec Auth si nécessaire) puis écriture
	write_fulltexts('5286C468C888B8857D1F8971080594B788D54013')
