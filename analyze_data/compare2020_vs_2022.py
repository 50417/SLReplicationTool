import logging
import sqlite3
import pandas as pd

from sqlite3 import Error

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


def get_all_vals_from_table(conn,sql):
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    results = [r[0] for r in rows]

    return results[0]

def get_22_project_id(conn,table):
    sql = "Select distinct file_id from "+table+"22_models"
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    results = [r[0] for r in rows]
    return results

def get_model_metric(conn,table,project_id):
    sql = "SELECT model_name,file_path,SCHK_block_Count,subsystem_count_top, agg_subsystem_count,\
        hierarchy_depth, libraryLinked_count, CComplexity, sim_time, alge_loop_cnt, target_hw, solver_type,\
        sim_mode,total_connH_cnt, total_desc_cnt, ncs_cnt, scc_cnt,unique_sfun_count, unique_mdl_ref_count \
        FROM "+table +"_models where is_test=-1 and is_lib=0 and file_id="+str(project_id)

    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    ans = {}
    for row in rows: 
        tmp = {'model_name':row[0],'SCHK_block_Count':row[2],'subsystem_count_top':row[3], 'agg_subsystem_count':row[4],\
            'hierarchy_depth':row[5], 'libraryLinked_count':row[6], 'CComplexity':row[7], 'sim_time':row[8],\
             'alge_loop_cnt':row[9], 'target_hw':row[10], 'solver_type':row[11],'sim_mode':row[12],\
             'total_connH_cnt':row[13], 'total_desc_cnt':row[14], 'ncs_cnt':row[15], 'scc_cnt':row[16],\
             'unique_sfun_count':row[17], 'unique_mdl_ref_count':row[18] }

        ans[row[1]] = tmp
    return ans

def convert_to_str(bar):
    if not isinstance(bar,str):
        bar = str(bar)
    return bar 

def compare_model(model_20b,model_22b):
    all_keys = model_20b.keys()
    for key in all_keys: 
        if model_20b[key] != model_22b[key]:
            print(model_20b['model_name'])
            print(key + "  2020b " + convert_to_str(model_20b[key]) + "| 2022b " + convert_to_str(model_22b[key]))

# p1 = 2020b version .. p2 = 2022b version
def compare_two_projects_models(p1,p2):
    p1_models = set(p1.keys())
    p2_models = set(p2.keys())

    models = p1_models.union(p2_models)

    for model in models:
        if model not in p1_models:
            print("Not in 2020b Version")
        elif model not in p2_models: 
            print("Not in 2022b version "+model)
        else: 
            compare_model(p1[model], p2[model])





# Update with SLNET_2020bvs2022b.sqlite file
db = ""
conn = create_connection(db)
project_ids = get_22_project_id(conn,'github')
for project_id in project_ids: 
    print("=====================")
    print("Comparing "+str(project_id))

    p_id_2020b = get_model_metric(conn,"Github",project_id)

    p_id_2022b = get_model_metric(conn,"Github22",project_id)

    compare_two_projects_models(p_id_2020b,p_id_2022b)
    print("=====================\n\n")

project_ids = get_22_project_id(conn,'matc')
for project_id in project_ids: 
    print("=====================")
    print("Comparing "+str(project_id))

    p_id_2020b = get_model_metric(conn,"matc",project_id)

    p_id_2022b = get_model_metric(conn,"matc22",project_id)

    compare_two_projects_models(p_id_2020b,p_id_2022b)
    print("=====================\n\n")