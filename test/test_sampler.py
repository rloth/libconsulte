#! /usr/bin/python3

import unittest

# the tested module
# £TODO check if import ok
import sampler

class TestSampler(unittest.TestCase):
	def test_1_value_lists(self):
		"Check field_value_lists.py contents (4 tuples or lists)."
		print()
		import field_value_lists
		self.assertIsInstance(field_value_lists.DATE, tuple)
		print("DATE: %i ranges" % len(field_value_lists.DATE))
		self.assertIsInstance(field_value_lists.GENRE, tuple)
		print("GENRE: %i cats" % len(field_value_lists.GENRE))
		self.assertIsInstance(field_value_lists.LANG, tuple)
		print("LANG: %i cats" % len(field_value_lists.LANG))
		self.assertIsInstance(field_value_lists.SCAT, tuple)
		print("SCICAT: %i cats" % len(field_value_lists.SCAT))
	
	def test_2_sample_ten(self):
		"Test size after 1 sample() run"
		print()
		mon_crit = 'corpusName'
		# (allow +/- 1 result length for roundup error)
		hit_index = sampler.sample(10, [mon_crit])
		self.assertTrue(len(hit_index) <= 11)
		self.assertTrue(len(hit_index) >= 9)
	
	def test_3_query_trace(self):
		"Check if we kept coherent trace of query 'crit:val'"
		print()
		mon_crit = 'corpusName'
		hit_index = sampler.sample(1, [mon_crit])
		# read index[some_id]['_q'] 
		id0 = next(iter(hit_index))
		first_query = hit_index[id0]['_q']
		left_side = first_query.split(':')[0]
		self.assertEqual(left_side, mon_crit)

if __name__ == '__main__':
	unittest.main(verbosity=2)