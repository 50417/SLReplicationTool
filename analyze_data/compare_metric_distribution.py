import logging
import sqlite3
from sqlite3 import Error
import time
from datetime import datetime
from statistics import variance, stdev
import pandas as pd
logging.basicConfig(filename='compare_metric_distribution.log', filemode='a',
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

def calculate_quartiles(list_of_vals):
	'''
	args:
		list_of_vals : sorted list
	'''
	list_of_vals.sort()
	sum_list = sum(list_of_vals)
	n = len(list_of_vals)
	mean = sum_list/n
	if n % 2 == 0:
		median1 = list_of_vals[n // 2]
		median2 = list_of_vals[n // 2 - 1]
		median = (median1 + median2) / 2
	else:
		median = list_of_vals[n // 2]

	return [round(list_of_vals[0],1),round(list_of_vals[n-1],1),round(mean,1),round(median,2),round(stdev(list_of_vals),1)]



def get_num_of_distinct_blk_type_per_project(conn,source,where_cond=None):
	if where_cond is not None:
		sql = "select file_id,count(DISTINCT blk_type) from "+source+"_blocks where "+where_cond+" group by file_id"
	else: 
		sql = "select file_id,count(DISTINCT blk_type) from "+source+"_blocks group by file_id"

	cur = conn.cursor()
	cur.execute(sql)

	rows = cur.fetchall()
	return [r[1] for r in rows]

def get_distinct_blk_type_quartile_per_project(conn,sources,where_cond=None):
	res_list = []
	for source in sources:
		if where_cond is not None:
			sql = "select file_id,count(DISTINCT blk_type) from "+source+"_blocks where "+where_cond+" group by file_id"
		else: 
			sql = "select file_id,count(DISTINCT blk_type) from "+source+"_blocks group by file_id"

		cur = conn.cursor()
		cur.execute(sql)

		rows = cur.fetchall()
		res_list.extend([r[1] for r in rows])
	quart_list = calculate_quartiles(res_list)
	return quart_list

def get_no_of_blk_in_subsys_quartile_per_project(conn,sources,where_cond=None):
	res_list = []
	for source in sources:
		if where_cond is not None:
			sql = "select file_id,MAX(block_count) from "+source+"_Subsys where "+where_cond+" group by file_id"
		else: 
			sql = "select file_id,MAX(block_count) from "+source+"_Subsys group by file_id"

		cur = conn.cursor()
		cur.execute(sql)

		rows = cur.fetchall()
		res_list.extend([r[1] for r in rows])
	quart_list = calculate_quartiles(res_list)
	return quart_list



def get_distinct_blk_type_quartile_per_model(conn,sources,where_cond=None):
	res_list = []
	for source in sources:
		if where_cond is not None:
			sql = "select file_id,file_path,MAX(block_count) from "+source+"_Subsys where "+where_cond+" group by file_id,file_path"
		else: 
			sql = "select file_id,file_path, MAX(block_count) from "+source+"_Subsys group by file_id,file_path"

		cur = conn.cursor()
		cur.execute(sql)

		rows = cur.fetchall()
		res_list.extend([r[2] for r in rows])
	quart_list = calculate_quartiles(res_list)
	return quart_list

def get_no_of_blk_in_subsys_quartile_per_model(conn,sources,where_cond=None):
	res_list = []
	for source in sources:
		if where_cond is not None:
			sql = "select file_id,file_path,count(DISTINCT blk_type) from "+source+"_blocks where "+where_cond+" group by file_id,file_path"
		else: 
			sql = "select file_id,file_path, count(DISTINCT blk_type) from "+source+"_blocks group by file_id,file_path"

		cur = conn.cursor()
		cur.execute(sql)

		rows = cur.fetchall()
		res_list.extend([r[2] for r in rows])
	quart_list = calculate_quartiles(res_list)
	return quart_list

def get_info_per_project(conn,source,col,where_cond = None):
	if col == "*":
		sql = "select file_id, count("+col+") c from "+source+"_models where is_lib=0 and is_test=-1 group by File_id"
	else:
		if where_cond is not None:
			sql = "select file_id, sum("+col+") c from "+source+"_models where is_lib=0 and is_test=-1 and "+where_cond+" group by File_id"
		else:
			sql = "select file_id, sum("+col+") c from "+source+"_models where is_lib=0 and is_test=-1 group by File_id"
	if col == "CComplexity":
		sql = sql.replace("sum","max")
	cur = conn.cursor()
	cur.execute(sql)

	rows = cur.fetchall()
	return [r[1] for r in rows]

def get_per_projects_quartiles(sources, conn, extra_where_cond = None):
	cols = ["*","SCHK_Block_count","total_ConnH_cnt","Agg_SubSystem_count","CComplexity","unique_mdl_ref_count","Alge_loop_Cnt","LibraryLinked_count"]
	where_cond = [None,None,None,None,"CComplexity>-1",None,"Alge_loop_Cnt>-1",None]
	if extra_where_cond is not None: 
		for i in range(len(where_cond)):
			if where_cond[i] is None: 
				where_cond[i] = ""
				where_cond[i] = where_cond[i] + " " + extra_where_cond
			else:
				where_cond[i] = where_cond[i] + ' and ' + extra_where_cond

	counter = 0
	ans = {}
	for col in cols:
		res_list = []
		for src in sources:
			res_list.extend(get_info_per_project(conn,src,col,where_cond[counter]))
		quart_list = calculate_quartiles(res_list)
		ans[col] = quart_list
		logging.info("Values in {} are: {}".format(col,' '.join(map(str, quart_list))))
		counter += 1
	return ans

def get_info_per_model(conn,source,col,where_cond = None):
	if where_cond is not None:
		sql = "select file_id,file_path, "+col+" from "+source+"_models where is_lib=0 and is_test=-1 and "+where_cond+" group by File_id,file_path"
	else:
		sql = "select file_id,file_path, "+col+" from "+source+"_models where is_lib=0 and is_test=-1 group by File_id,file_path"
	cur = conn.cursor()
	cur.execute(sql)

	rows = cur.fetchall()
	return [r[2] for r in rows]

def get_per_model_quartiles(sources, conn, extra_where_cond = None):
	cols = ["SCHK_Block_count","total_ConnH_cnt","Agg_SubSystem_count","CComplexity","unique_mdl_ref_count","Alge_loop_Cnt","LibraryLinked_count"]
	where_cond = [None,None,None,"CComplexity>-1",None,"Alge_loop_Cnt>-1",None]
	if extra_where_cond is not None: 
		for i in range(len(where_cond)):
			if where_cond[i] is None: 
				where_cond[i] = ""
				where_cond[i] = where_cond[i] + " " + extra_where_cond
			else:
				where_cond[i] = where_cond[i] + ' and ' + extra_where_cond

	counter = 0
	ans = {}
	for col in cols:
		res_list = []
		for src in sources:
			res_list.extend(get_info_per_model(conn,src,col,where_cond[counter]))
		quart_list = calculate_quartiles(res_list)
		ans[col] = quart_list
		logging.info("Values in {} are: {}".format(col,' '.join(map(str, quart_list))))
		counter += 1
	return ans

def convert_df_to_str(df):
	res =""
	for name in df:
		if(not pd.isna(name)):

			res+='"'+name[:-1]+'"'+','
	res = res[:-1]
	return res

def format_num_for_print(num):
	return "{:,.1f}".format(num)

def main():
	# Update with SLnet database aka slnet_2020R.sqlite
	slnet_db = ""
	slnet_conn = create_connection(slnet_db)
	slnet_sources = ["GitHub","MATC"]

	slnet_per_project = get_per_projects_quartiles(slnet_sources,slnet_conn)
	slnet_per_project["blk_type"] = get_distinct_blk_type_quartile_per_project(slnet_conn,slnet_sources)
	slnet_per_project["blk_subsys"] = get_no_of_blk_in_subsys_quartile_per_project(slnet_conn,slnet_sources)

	slnet_per_model = get_per_model_quartiles(slnet_sources,slnet_conn)
	slnet_per_model["blk_type"] =  get_distinct_blk_type_quartile_per_model(slnet_conn,slnet_sources)
	slnet_per_model["blk_subsys"] = get_no_of_blk_in_subsys_quartile_per_model(slnet_conn,slnet_sources)
	

	# Update with Boll's database aka 
	slc_boll_db = "" 
	slc_boll_conn = create_connection(slc_boll_db)
	slc_boll_sources = ["All"]

	slc_boll_per_project = get_per_projects_quartiles(slc_boll_sources,slc_boll_conn)
	slc_boll_per_project["blk_type"] = get_distinct_blk_type_quartile_per_project(slc_boll_conn,slc_boll_sources)
	slc_boll_per_project["blk_subsys"] = get_no_of_blk_in_subsys_quartile_per_project(slc_boll_conn,slc_boll_sources)
	
	slc_boll_per_model = get_per_model_quartiles(slc_boll_sources,slc_boll_conn)
	slc_boll_per_model["blk_type"] = get_distinct_blk_type_quartile_per_model(slc_boll_conn,slc_boll_sources)
	slc_boll_per_model["blk_subsys"] = get_no_of_blk_in_subsys_quartile_per_model(slc_boll_conn,slc_boll_sources)

	#Update with reprodcing slc's database  
	slc_r_db = ""
	slc_r_conn = create_connection(slc_r_db)
	df = pd.read_csv('slcorpus-0.csv')

	mdl_names = convert_df_to_str(df["Tutorial"])
	mdl_names =mdl_names + ","+convert_df_to_str(df["Simple"])
	mdl_names =mdl_names + ","+convert_df_to_str(df["Advanced"])
	mdl_names =mdl_names + ","+convert_df_to_str(df["Others"])

	slc_r_sources = ["GitHub","MATC","Others","SourceForge","Tutorial"]
	extra_where_cond = "substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ")"
	slc_r_per_project = get_per_projects_quartiles(slc_r_sources,slc_r_conn,extra_where_cond) 
	slc_r_per_project["blk_type"]  = get_distinct_blk_type_quartile_per_project(slc_r_conn,slc_r_sources,extra_where_cond)
	slc_r_per_project["blk_subsys"] = get_no_of_blk_in_subsys_quartile_per_project(slc_r_conn,slc_r_sources,extra_where_cond)

	slc_r_per_model = get_per_model_quartiles(slc_r_sources,slc_r_conn,extra_where_cond) 
	slc_r_per_model["blk_type"]  = get_distinct_blk_type_quartile_per_model(slc_r_conn,slc_r_sources,extra_where_cond)
	slc_r_per_model["blk_subsys"] = get_no_of_blk_in_subsys_quartile_per_model(slc_r_conn,slc_r_sources,extra_where_cond)

	print(slnet_per_project)
	print(slc_boll_per_project)
	print(slc_r_per_project)

	print(slnet_per_model)
	print(slc_boll_per_model)
	print(slc_r_per_model)

	cols = ["*","SCHK_Block_count","blk_type","total_ConnH_cnt","Agg_SubSystem_count","CComplexity","unique_mdl_ref_count","Alge_loop_Cnt","LibraryLinked_count","blk_subsys"]
	col_header = ["Model","Block","Block type","Signal line","Subsystem","CC","Mdl Ref","Algebraic L.","Lib-Linked Block","Subsys Block"]
	for col_idx in range(len(cols)):
		col = cols[col_idx]
		header = col_header[col_idx]
		
		per_project = "\\multirow{2}{*}{"+header+"} & p"
		per_model = " & m" 
		for i in range(5):
			per_project+= " & "+format_num_for_print(slc_r_per_project[col][i])
			per_project+= " & "+format_num_for_print(slc_boll_per_project[col][i])
			per_project+= " & "+format_num_for_print(slnet_per_project[col][i])
			if col in slnet_per_model:
				per_model+= " & " + format_num_for_print(slc_r_per_model[col][i])
				per_model+= " & "  + format_num_for_print(slc_boll_per_model[col][i])
				per_model+= " & " + format_num_for_print(slnet_per_model[col][i])
			else: 
				per_model+= " & " + "-"
				per_model+= " & " + "-"
				per_model+= " & " + "-"

		per_project += "\\\\"
		per_model += "\\\\"
		print(per_project)
		print(per_model)



	

if __name__ == '__main__':
	main()
