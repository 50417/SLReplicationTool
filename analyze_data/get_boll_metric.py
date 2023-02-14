import logging
import sqlite3
from sqlite3 import Error
import time
from datetime import datetime
from statistics import variance, stdev
import pandas as pd
import json
logging.basicConfig(filename='get_boll_metric.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)


def create_connection(db_file):
	""" create a database connection to the SQLite database
		specified by the db_file
	:param db_file: database file
	:return: Connection object or None
	"""
	conn = None
	try:
		conn = sqlite3.connect(db_file)
	except Error as e:
		print(e)

	return conn


def format_num_for_print(num):
	return "{:,.0f}".format(num)

def get_count(conn,sql):
	cur = conn.cursor()
	res = cur.execute(sql)
	rows = cur.fetchall()
	ans = ""
	for row in rows:
		
		for r in row:
			if ans != "":
				ans +=" & "
			ans += format_num_for_print(r)

	return ans

def get_map_count(conn,sql):
	cur = conn.cursor()
	res = cur.execute(sql)
	rows = cur.fetchall()
	ans = {}
	for row in rows:
		ans[row[0]] = format_num_for_print(row[1])
	return ans


def add_zero_if_no_key(hash_map,key):
	if key in hash_map.keys():
		return " & "+hash_map[key]
	else:
		return " & 0"

def get_model_metric(conn,category=None):
	category_clause = ""
	if category is not None:
		if category == 'no information':
			category += "' or category = 'unknown"
		category_clause = "  and file_id in (Select id from All_projects where category ='"+category+"') "
	

	mdl_analyzed_sql = "select count(*) from all_models where is_Lib = 0  and is_test = -1"
	mdl_compiled_sql = "select count(*) from all_models where is_Lib = 0  and is_test = -1 and compiles = 1"
	hierar_sql="select count(*) from all_models where is_Lib = 0 and is_test = -1  and Hierarchy_depth>1"
	hierar_sql_org = "select count(*) from all_models where is_Lib = 0 and is_test = -1  and C_corpus_hierar_depth>1"
	blk_conn_counts_sql = "select sum(SCHK_block_count),sum(C_corpus_blk_count),sum(total_ConnH_cnt),sum(C_corpus_conn + C_corpus_hidden_conn) from  all_models where is_Lib = 0 and is_test = -1"
	
	res = ""
	for sql in [mdl_analyzed_sql,mdl_compiled_sql,hierar_sql,hierar_sql_org,blk_conn_counts_sql]:
		if res != "":
			res += " & "
		sql += category_clause
		res += get_count(conn,sql)

	solver_type_sql = "select solver_type,count(solver_type) from all_models where is_Lib = 0 and is_test = -1 "+ category_clause+" group by solver_type" 
	solver_map = get_map_count(conn,solver_type_sql)
	sim_mode_sql = "select sim_mode,count(sim_mode) from all_models where is_Lib = 0 and is_test = -1 "+ category_clause+" group by sim_mode"
	sim_map = get_map_count(conn,sim_mode_sql)

	res += add_zero_if_no_key(solver_map,'Fixed-step')
	res += add_zero_if_no_key(solver_map,'Variable-step')


	res += add_zero_if_no_key(sim_map,'normal')
	res += add_zero_if_no_key(sim_map,'external')
	res += add_zero_if_no_key(sim_map,'processor-in-the-loop (pil)')
	res += add_zero_if_no_key(sim_map,'accelerator')
	res += add_zero_if_no_key(sim_map,'rapid-accelerator')

	res += "\\\\"
	if category is not None:
		if category == "no information' or category = 'unknown":
			res = "no information & "+ res
		else:
			res = category+" & "+res
	else:
		res =" & "+res
	return res
	





def main():
	db = ""
	conn = create_connection(db)
	categories = ['academic','industry-mathworks','industry','no information',None]
	for category in categories:
		print(get_model_metric(conn,category))
main()



