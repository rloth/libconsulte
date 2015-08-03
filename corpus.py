#! /usr/bin/python3
"""
Common corpus management tools:
  dociteration(crit)
  corpus_save(tsv)
  formatter(self, tgt_format)
"""
__author__    = "Romain Loth"
__copyright__ = "Copyright 2014-5 INIST-CNRS (ISTEX project)"
__license__   = "LGPL"
__version__   = "0.1"
__email__     = "romain.loth@inist.fr"
__status__    = "Dev"

from glob          import glob
from os            import path
from collections   import defaultdict

# pour option tree
from json          import dumps

# local dependency

# CONSTANT mapping standard fields  (the keys are passed as outfields to queries)
# (key: API Name, val: local name <= the value is actually not used)
STD_MAP = {
	'id'              : '_id',
	'corpusName'      : '_src',
	'doi'             : '_doi',
	'title'           : 'title',
	'language'        : 'lang',
	'publicationDate' : 'year',
	'host.issn'       : 'in_issn',
	'serie.issn'       : 'in_issn',  # alternative au précédent
	'genre'           : 'genre_list',
	'author.name'     : 'author_list'
}


class Corpus(object):
	"""
	A collection of docs with their metadata
	and their diverse input text formats.
	
	Meta is like the main dict. It can be: 
	 - translated (teiHeader <=> json <=> csv) 
	 - agregated (eg avg freq per subclass)
	 - converted to filename
	
	Data is like an attachment, and can be
	 - read from any source (FS/API: pdf, tei, native xml)
	 - matched upon (xtok)
	 - saved to FS
	"""
	
	def __init__(self, name, *otherargs):
		"""
		Calls the relevant constructor from the arguments
		"""
		if type(name) == str:
			self.name = name
		else:
			raise TypeError("new Corpus() needs a name str as 1st arg")
		
		# default slots
		self._info_lookup = defaultdict(Docinfo)
		#~ self._data_contents = {}
		
		# pass for further population
		if len(otherargs):
			my_type = type(otherargs[0])
			if my_type == str:
				self.__init_from_dir(*otherargs)
			elif my_type == list:
				self.__init_from_api(*otherargs)
			else:
				print("=======otherargs========")
				print(otherargs)
				print("========================")
				raise NotImplementedError("new Corpus() unknown mode %s" % my_type)
	
	def __init_from_dir(self, rootpath):
		"""
		:param rootpath: An os.path identifying the root directory for this corpus.
		"""
		handles = []
		if path.exists(rootpath):
			handles = glob(rootpath)
		self._file_ids = handles
		self._info_lookup = defaultdict(Docinfo)
	
	def __init_from_api(self, hit_list):
		"""
		:param hit_dict: A json.loads() output 
		                 containing a list of document metadata
		"""
		for info in hit_list:
			idi = info['id']
			
			# metadata structure
			md_struct = Docinfo(info)
			
			# corpus internals
			self._info_lookup[idi] = md_struct
		
		self._data_contents = {}
	
	
	def __len__(self):
		"""Provides len(my_corpus)             -- corpus as container"""
		return len(self._info_lookup)
	
	def __contains__(self, key):
		"""Provides 'in' checks for my_corpus  -- corpus as container"""
		return key in self._info_lookup
	
	def __iter__(self):
		"""Provides 'in' lists for my_corpus      corpus as container"""
		return self._info_lookup.__iter__()
	
	def __getitem__(self, k):
		"""Provides my_corpus[an_ID]           -- corpus as container"""
		if k not in self._info_lookup:
			raise IndexError("ID'%s' not in Corpus %s" % (k, self.name))
		else:
			return self._info_lookup[k]
	
	def __setitem__(self, k, val):
		"""Provides assign to my_corpus[an_ID] -- corpus as container"""
		if type(val) is not Docinfo:
			raise TypeError("New corpus values must be corpus.Docinfo() objects")
		self._info_lookup[k] = val
	
	def __delitem__(self, k):
		"""Provides del(my_corpus[an_ID])      -- corpus as container"""
		if k not in self._info_lookup:
			raise IndexError("ID'%s' not in Corpus %s" % (k, self.name))
		else:
			# clean two dicts (meta + data)
			del self._info_lookup[k]
			#~ del self._data_contents[k]
	
	def fileids(self):
		"""For nltk.corpus compatibility"""
		return self._info_lookup.keys()
	
	def keys(self):
		"""For dict compatibility"""
		return self._info_lookup.keys()
	
	def items(self):
		"""For dict compatibility"""
		return self._info_lookup.items()

	def values(self):
		"""For dict compatibility"""
		return self._info_lookup.values()
	
	def process(self):
		"""
		Throws all data_contents in a transformation (XSLT, extraction)
		"""
		print('TODO xslt')
		pass
	
	def save(self, tgtpath):
		pass




class Docinfo(dict):
	"""
	Hash struct containing main metadata attr:values for a given Doc
	"""
	def __init__(self):
		"""
		Builds all specif required slots with empty/unknown values
		Any other slots are allowed (it's just a handy dict after all)
		"""
		self['_id'] = None
		self['_doctype'] = None
		self['_calibre'] = None
		self['_src'] = None
		self['_doi'] = None
		self['_year'] = None
		self['title'] = None
		self['in_issn'] = None
		self['author_list'] = []
		
		print("Docinfo empty init")
	
	def __init__(self, std_json_hit):
		"""
		Builds all required slots with json values from API's outfields
		"""
		
		self['_id']         = std_json_hit['id']
		self['_doctype']    = 'TODO type'
		self['_calibre']    = 'TODO calib'
		self['_src']        = std_json_hit['corpusName'][0:3]
		self['_doi']        = std_json_hit['doi'][0]
		
		# potentially empty
		if 'title' in std_json_hit:
			self['title']     = std_json_hit['title']
		else:
			self['title']     = "_UNTITLED_"
		
		if 'publicationDate' in std_json_hit:
			self['year']      = std_json_hit['publicationDate'][0:4]
		else:
			self['year']      = "_XXXX_"
		
		if 'host' in std_json_hit and 'issn' in std_json_hit['host']:
			self['in_issn'] = std_json_hit['host']['issn'][0]
		elif 'serie' in std_json_hit and 'issn' in std_json_hit['serie']:
			self['in_issn'] = std_json_hit['serie']['issn'][0]
		else:
			self['in_issn'] = "_NOISSN_"
		
		if 'genre' in std_json_hit and len(std_json_hit['genre']):
			self['genre_list'] = std_json_hit['genre']  # TODO check genre vals
		
		if 'author' in std_json_hit: # and 'name' in std_json_hit['author'][0]:
			self['author_list'] = [au['name'] for au in std_json_hit['author']]
		else:
			self['author_list'] = ["_UNKNOWN_"]
	
	def to_tab(self):
		return "\t".join([
							self['_id'],
							self['_src'],
							self['year'],
							self['in_issn'],
							",".join(self['author_list'])[0:12]+("... etal." if len(self['author_list']) > 1 else "..."),
							self['title']
						]
					)
	
	def to_filename(self):
		"""
		Creates a human readable file name from work records.
		Expected dict keys are "-src" (corpus),
		"""
		return "-".join(
						[
						str_safe(self['_id']),
						str_safe(self['_src']),
						str_safe(self['author_list'][0].split()[-1]),
						str_safe(self['year']),
						str_safe(self['title'][0:30])
						]
					)
	
	def to_teiHeader(self):
		temp_indents = "\n" + "  " * 4
		author_tei_str = temp_indents.join(
			["<author><persName>"+au+"</persName></author>" 
				for au in self['author_list']]
			)
		xmlstr="""
<teiHeader>
  <fileDesc>
    <titleStmt>
      <title>%s</title>
    </titleStmt>
    <sourceDesc>
      <bibl>
        <idno type="istex">%s</idno>
        %s
        <idno type="pISSN">%s</idno>
        <imprint>
          <date type="published" when="%s"/>
        </imprint>
        <idno type="DOI">%s</idno>
      </bibl>
    </sourceDesc>
  </fileDesc>
</teiHeader>
""" % (self['title'], self['_id'], author_tei_str, self['in_issn'], 
		self['year'], self['_doi'])
		
		return xmlstr


# todo mettre à part dans une lib
def str_safe(a_string=""):
	from re import sub
	return sub("[^A-Za-z0-9àäçéèïîøöôüùαβγ]+","_",a_string)

class Index(dict):
	"""
	a hash of tags/facets over documents
	------------------------------------
	Each dict key is a category among a list of strings (possible outcomes)
	Each value is a standard indexitem hash containing:
	  - reflist: list of CorpusDocs        textcontentvalue[]
	  - _n : the len of the reflist        micro metavalue
	  - 
	
	Next to it's main hash content, the index object also carries some
	of his own metavalues at the macro scale:
	  - __catmap__ = __idx__.keys = a list of possible keys
	
	"""
	
	def __init__(self, *a_dicts_args):
		dict.__init__(*a_dicts_args)
	
	def index_to_jsontree(my_index):
		'''
		Converts an info hash to a recursive count hash then to a jsontree
		
		/!\ specific to 2-level infos with 'co' and 'yr' keys
		
		£TODO make more generic and put it in a lib ?
		'''
		# hierarchical counts structure to carry over "info" observations
		# £perhaps could be generated while sampling ?
		sizes = defaultdict(lambda: defaultdict(int))
		
		# the first limit is always implicitly the year "-Inf" is is ignored
		date_limits = [yr[0] for yr in field_value_lists.DATE[1:]]
		
		for did, info in my_index.items():
			# todo retrieve 2 vals: val_corpus and annee
			
			val_date = ""
			
			# date bins
			prev = "*"
			n_lims = len(date_limits)
			for i,lim in enumerate(date_limits):
				if i < n_lims - 1:
					if int(annee) < lim:
						val_date = prev + "-" + str(lim-1)
						break
				else:
					val_date = str(lim) + "-*"
				prev = str(lim)
			
			
			# count
			sizes[val_corpus][val_date] += 1
		
		# step 2: convert sizecounts to json-like structure (ex: flare.json)
		jsonmap = []
		
		# £todo do this recursively for (nestedlevel > 2) support
		for k in sizes:
			submap = []
			for child in sizes[k]:
				new_json_leaf = {'name':child, 'size':sizes[k][child]}
				submap.append(new_json_leaf)
			
			new_json_nonterm = {'name':k, 'children':submap}
			jsonmap.append(new_json_nonterm)
		
		print(dumps(jsonmap, indent=True))
		jsontree = {'name': 'ech_res', 'children': jsonmap}
		return jsontree

########################################################################
if __name__ == '__main__':
	
	# test de création d'un Docinfo ################################
	print("TEST: Docinfo filled init")
	a_dict_hit = {
				'genre': ['article', 'Serial article'],
				'doi': ['10.1002/spe.1078'],
				'corpusName': 'wiley',
				'host': {'issn': ['0038-0644']},
				'id': '1E12489FCBA463C17B03C6717338AE5C7116A73E',
				'title': 'Agile software product lines: a systematic mapping study', 
				'publicationDate': '2011-07',
				'author': [
					{'name': 'Ivonei Freitas da Silva'},
					{'name': 'Paulo Anselmo da Mota Silveira Neto'},
					{'name': 'Pádraig O\'Leary'},
					{'name': 'Eduardo Santana de Almeida'},
					{'name': 'Silvio Romero de Lemos Meira'}
					]
				}
	my_doc_md = Docinfo(a_dict_hit)
	print(my_doc_md.to_tab())
	
	################################################################
	# création à partir d'une liste de hits
	import api
	jsonhits = api.search("agile", limit=3, outfields=STD_MAP.keys())
	my_corpus = Corpus("untitled", jsonhits)
	
	for k in my_corpus:
		print(my_corpus[k].to_teiHeader())
	
	print("LEN:", len(my_corpus))