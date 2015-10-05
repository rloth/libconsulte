#! /usr/bin/python3
"""
Query the ISTEX API (ES: lucene q => json doc)
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.2"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

from json            import loads
from urllib.parse    import quote
from urllib.request  import urlopen, HTTPBasicAuthHandler, build_opener, install_opener
from urllib.error    import URLError
from getpass   import getpass
from os import path
from sys import stderr
from re import sub
from json import dumps  # pretty printing si debug ou main

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
	"""
	Get remote url *that contains a ~json~* 
	and parse it
	"""
	
	# print("> api._get:%s" % my_url, file=stderr)
	
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


def _bget(my_url, user=None, passw=None):
	"""
	Get remote auth-protected url *that contains a ~file~* 
	and pass its binary data straight from remote response
	(for instance when retrieving fulltext from ISTEX API)
	"""
	
	# /!\ attention le password est en clair ici /!\
	# print ("REGARD:", user, passw,     file=stderr)
	
	no_contents = False
	
	auth_handler = HTTPBasicAuthHandler()
	auth_handler.add_password(
			realm  = 'Authentification sur api.istex.fr',
			uri    = 'https://api.istex.fr',
			user   = user,
			passwd = passw)
	install_opener(build_opener(auth_handler))
	
	print("GET bin (user:%s)" % user, file=stderr)
	
	# contact
	try:
		remote_file = urlopen(my_url)
		
	except URLError as url_e:
		if url_e.getcode() == 401:
			raise AuthWarning("need_auth")
		else:
			# 404 à gérer *sans quitter* pour les fulltexts en nombre...
			no_contents = True
			print("api: HTTP ERR no %i (%s) sur '%s'" % 
				(url_e.getcode(),url_e.msg, my_url), file=stderr)
				# pour + de détail
				# print ("ERR.info(): \n %s" % url_e.info(),file=stderr)
	
	if no_contents:
		return None
	else:
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
	
	# décompte à part
	n_docs = count(url_encoded_lucene_query, already_escaped=True)
	# print('%s documents trouvés' % n_docs)
	
	# construction de l'URL
	base_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&output=' + ",".join(outfields)
	# debug
	# print("api.search().base_url:", base_url)
	
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


def count(q, api_conf=DEFAULT_API_CONF, already_escaped=False):
	"""
	Get total hits for a lucene query on ISTEX api.
	"""
	# préparation requête
	if already_escaped:
		url_encoded_lucene_query = q
	else:
		url_encoded_lucene_query = my_url_quoting(q)
	
	# construction de l'URL
	count_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&size=1'
	
	# requête
	json_values = _get(count_url)
	
	return int(json_values['total'])


def write_fulltexts(DID, base_name=None, api_conf=DEFAULT_API_CONF, tgt_dir='.', login=None, passw=None, api_types=['fulltext/pdf', 'metadata/xml']):
	"""
	Get XML metas, TEI, PDF, ZIP fulltexts etc. for a given ISTEX-API document.
	
	"""
	# vérification
	for at in api_types:
		if at not in ['fulltext/pdf', 
						'fulltext/tei',
						'fulltext/txt',
						'fulltext/zip',
						'metadata/xml',
						'metadata/mods',
						]:
			raise KeyError("Unknown filetype %s" % at)
	
	# default name is just the ID and the fileextension
	if not base_name:
		base_name = DID
	
	# préparation requête
	da_url = 'https://'+api_conf['host']+'/'+api_conf['route']+'/'+DID
	
	for at in api_types:
			response = _bget(da_url+'/'+at, user=login, passw=passw)
			
			# _bget renvoie None pour les (rares) 404 
			#      (ex: demande tei a ecco)
			if response is not None:
				
				# ext par défaut: partie droite de la route de l'api
				ext = at.split('/')[1]
				
				tgt_path = path.join(tgt_dir, base_name+'.'+ext)
				
				fh = open(tgt_path, 'wb')
				fh.write(response)
				fh.close()


def write_fulltexts_loop_interact(list_of_ids, list_of_basenames=None, api_conf=DEFAULT_API_CONF, tgt_dir='.', api_types=['fulltext/pdf', 'metadata/xml']):
	"""
	Calls the preceding function in a loop for an entire list,
	
	With optional interactive authentification step:
	  - IF (login and passw are None AND _bget raises AuthWarning)
	    THEN ask user
	
	"""
	# test sur le premier fichier: authentification est-elle nécessaire ?
	need_auth = False
	
	first_doc_id = list_of_ids[0]
	if list_of_basenames:
		first_base_name = list_of_basenames[0]
	else:
		first_base_name = None
	
	try:
		# test with no auth credentials
		write_fulltexts(
			first_doc_id, first_base_name, 
			tgt_dir=tgt_dir,
			api_types=api_types
			)
		print("API:retrieving doc no 1 from %s" % api_types)
	except AuthWarning as e:
		print("NB: l'API veut une authentification pour les fulltexts SVP...",
				file=stderr)
		need_auth = True
	
	# récupération avec ou sans authentification
	if need_auth:
		my_login = input(' => Nom d\'utilisateur "ia": ')
		my_passw = getpass(prompt=' => Mot de passe: ')
		for i, did in enumerate(list_of_ids):
			if list_of_basenames:
				my_bname = list_of_basenames[i]
			else:
				my_bname = None
			
			print("API:retrieving doc no %s from %s" % (str(i+1),api_types))
			try:
				write_fulltexts(
					did,
					base_name = my_bname,
					tgt_dir=tgt_dir,
					login=my_login,
					passw=my_passw,
					api_types= api_types
				)
			except AuthWarning as e:
				print("authentification refusée :(")
				my_login = input(' => Nom d\'utilisateur "ia": ')
				my_passw = getpass(prompt=' => Mot de passe: ')
	
	else:
		for i, did in enumerate(list_of_ids):
			# on ne refait pas le 1er car il a marché
			if i == 0:
				continue
			if list_of_basenames:
				my_bname = list_of_basenames[i]
			else:
				my_bname = None
			print("API:retrieving doc no %s from %s" % (str(i+1),api_types))
			write_fulltexts(
				did,
				base_name=my_bname,
				tgt_dir=tgt_dir,
				api_types=api_types
			)


def terms_facet(facet_name, q="*", api_conf=DEFAULT_API_CONF):
	"""
	Get list of possible values/outcomes for a given field, with their counts (within the perimeter of the query q).
	
	output format {"facet_value_1": count_1, ...}
	"""
	# préparation requête
	url_encoded_lucene_query = my_url_quoting(q)
	
	# construction de l'URL
	facet_url = 'https:' + '//' + api_conf['host']  + '/' + api_conf['route'] + '/' + '?' + 'q=' + url_encoded_lucene_query + '&facet=' + facet_name
	
	# requête
	json_values = _get(facet_url)
	key_counts = json_values['aggregations'][facet_name]['buckets']
	
	
	# simplification de la structure
	# [
	#  {'docCount': 8059500, 'key': 'eng'},
	#  {'docCount': 1138473, 'key': 'deu'}
	# ]
	# => sortie + compacte:
	#    {'eng': 8059500, 'deu': 1138473 }
	simple_dict = {}
	for record in key_counts:
		k = record['key']
		n = record['docCount']
		
		simple_dict[k] = n
	
	return simple_dict


def my_url_quoting(a_query):
	"""
	URL-escaping support with extended support to avoid
	lucene operators or API unsupported chars (afaik: none)
	
	/!\ PRÉREQUIS /!\ : 
	  les parenthèses ont 2 statuts différents selon si elles sont pour
	  la syntaxe lucene ou si c'est un contenu du fragment à matcher (token)
	   - si pour la syntaxe lucene : seront gérées ici (actuellement via quote.safe)
	   - si partie du texte à matcher => à transformer EN AMONT dans le code 'métier'
	     par exemple en wildcard '?' (car ici ce serait très dur de les reconnaître !!!)
	   
	   DONC:
	   toute '(' sera ici gardée telle quelle via quote(..safe='(') #
	   toute ')' sera ici gardée telle quelle via quote(..safe=')') #
	
	/!\ NE PAS ESCAPER UNE REQUÊTE DEUX FOIS /!\
	"""
	#print("AVANT ESCAPE:", a_query)
	
	# (1) préalables "astuces de recherches"
	# --------------------------------------
	# 1a - un '~' provenant de l'OCR voulait dire 'caractère incertain'
	#    ==> du coup on le remplace par le wildcard '?' qui veut dire 
	#        la même chose dans l'univers lucene
	a_query = sub('~', "?", a_query)
	
	# 1b - si on a un slash *dans* la requête il est un token à 
	#      matcher (contenu) mais pour garantir de ne pas interférer
	#      avec l'URL ==> aussi wildcard '?'
	a_query = sub(r'/','?', a_query)
	
	# (2) fonction centrale: urllib.parse.quote()
	# -------------------------------------------
	esc_query = quote(a_query, safe=":")
	
	# (3) post-traitements de validation
	# -----------------------------------
	# lucene: les jokers "?" aka '%3F' interdits en début et fin de mot
	esc_query = sub('^%3F', "", esc_query)
	esc_query = sub('%20%3F', "%20", esc_query)
	esc_query = sub('%3F%20', "%20", esc_query)
	esc_query = sub('%3F$', "", esc_query)
	
	#print("APRÈS ESCAPE:", esc_query)
	
	return esc_query


########################################################################
if __name__ == '__main__':
	
	# test de requête simple
	q = input("test d'interrogation API ISTEX (entrez une requête Lucene):")
	
	print("Vos 3 premiers matchs:")
	print(
		dumps(
			search(
				q, 
				limit=3, 
				outfields=[
					'genre',
					'host.pages.first',
					'host.title',
					'host.volume',
					'id',
					'publicationDate'
					'title',
					]
			), 
		indent=2,
		sort_keys=True,
		)
	)
