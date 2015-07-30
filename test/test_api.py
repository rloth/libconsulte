#! /usr/bin/python3

import unittest

# tools
from urllib.request   import urlopen
from http.client      import HTTPResponse

# the tested module
# £TODO check if import ok
import api

class TestApi(unittest.TestCase):
	def setUp(self):
		# shorthand for the params of our api module
		self.host = api.DEFAULT_API_CONF['host']
		self.route = api.DEFAULT_API_CONF['route']
		self.full_route = 'https://'+self.host+'/'+self.route+'/'
	
	def test_1_connect_host(self):
		"Checks if API host URL responding"
		try:
			response = urlopen('http://' + self.host)
		except Exception:
			response = "no_response"
		self.assertIsInstance(response, HTTPResponse)
	
	def test_2_query_route(self):
		"Checks if API returning json hitlist + total"
		json_dic = api._get(self.full_route+'?q='+'*')
		self.assertIsInstance(json_dic['hits'], list)
		self.assertIsInstance(json_dic['total'], int)
	
	def test_3_get_text_pdf(self):
		"Checks if API serving fulltexts (PDF)"
		test_id = 'F6E41E226B3EAA27E5BC4D76C0FDCEC30AC92984'
		raw_file = api._sget(
		               self.full_route
		               + test_id
		               +'/fulltext/pdf'
		               )
		self.assertIsInstance(raw_file, bytes)
		self.assertEqual(raw_file[0:4], b'%PDF')
	
	def test_4_get_text_tei(self):
		"Checks if API serving fulltexts (TEI)"
		test_id = 'F6E41E226B3EAA27E5BC4D76C0FDCEC30AC92984'
		tei_file = api._sget(
		               self.full_route
		               + test_id
		               +'/fulltext/tei'
		               )
		tei = tei_file.decode('UTF-8')
		self.assertEqual(tei[0:5], '<?xml')


if __name__ == '__main__':
	unittest.main(verbosity=2)