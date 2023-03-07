import logging
import sqlite3
from sqlite3 import Error

def get_all_vals_from_table(conn,sql):
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    results = [r[0] for r in rows]

    return results[0]

def get_project_ids_from_table(conn,sql):
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    results = [r[0] for r in rows]
    ans = ""
    for i in range(len(results)-1): 
        ans+=str(results[i]) + ", "
    ans += str(results[len(results)-1])
    return len(results),ans


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

def get_code_generating_models_project(conn,table, where_cond = None):
    embedded_boll_sql = "select count(distinct FILE_ID) from "+table+"_code_gen where Embeddedcoder = 1 "
    if where_cond is not None:
        embedded_boll_sql += where_cond
    embedded_boll = get_all_vals_from_table(conn,embedded_boll_sql)
    #print(" Project with models configured to generate code using Embedded Coder using boll's heuristics")
    #print("Embedded boll's heuristic: {}".format(embedded_boll))

    target_link_boll_sql = "select count(distinct FILE_ID) from "+table+"_code_gen where TargetLink = 1 "
    if where_cond is not None:
        target_link_boll_sql += where_cond
    target_link_boll = get_all_vals_from_table(conn,target_link_boll_sql)
    #print(" Project with models configured to generate code using Target Link using boll's heuristics")
    #print("Target Link boll's heuristic: {}".format(target_link_boll))


    embedded_sql = "select count(distinct FILE_ID) from "+table+"_code_gen where System_Target_File in  ('ert.tlc','ert_shrlib.tlc') and Solver_Type =='Fixed-step' "
    if where_cond is not None:
        embedded_sql += where_cond
    embedded = get_all_vals_from_table(conn,embedded_sql)
    #print(" Project with models configured to generate code using Embedded Coder ")
    #print("Embedded : {}".format(embedded))

    grt_sql = "select count(distinct FILE_ID) from "+table+"_code_gen where System_Target_File in  ('grt.tlc') and Solver_Type =='Fixed-step' "
    if where_cond is not None:
        grt_sql += where_cond
    grt = get_all_vals_from_table(conn,grt_sql)
    #print(" Project with models configured to generate code using grt  ")
    #print("GRT : {}".format(grt ))
    
    others_sql = ' select count(distinct FILE_ID) from '+table+'_code_gen where System_Target_File not in  ("grt.tlc","ert.tlc","ert_shrlib.tlc") and (System_Target_File in ("rsim.tlc","rtwsun.tlc")  or Solver_Type =="Fixed-step") '
    if where_cond is not None:
        others_sql += where_cond
    others = get_all_vals_from_table(conn,others_sql)
    #print(" Project with models configured to generate code using toolbox other than Embedded Coder and GRT based ")
    #print("Others : {}".format(others ))

    total_sql = '  select count(distinct FILE_ID) from '+table+'_code_gen where (System_Target_File in  ("rsim.tlc","rtwsun.tlc")  or ( System_Target_File not in  ("rsim.tlc","rtwsun.tlc") and Solver_Type =="Fixed-step")) '
    if where_cond is not None:
        total_sql += where_cond
    total = get_all_vals_from_table(conn,total_sql)
    #print(" Project with models configured to generate code ")
    #print("Total: {}".format(total ))

    return str(embedded_boll)+" & "+str(embedded)+" & "+str(grt)+" & "+str(others)+" & "+str(total)
    

def main():
    slc_20r_2020b_database = ""
    table = "All"
    category = ["academic","industry-mathworks","industry","no information","unknown"]
    row_title = ["Academic","Industry-M","Industry","No Info","UNK"]
    # create a database connection
    conn = create_connection(slc_20r_2020b_database)
    for i in range(len(category)): 
        project_sql = "Select ID from "+table+"_projects where category = '"+ category[i]+"'"
        no_of_projects, id_sql_when_cond = get_project_ids_from_table(conn,project_sql)
        where_cond = "AND FILE_ID IN ("+id_sql_when_cond+")"
        print(row_title[i]+" & "+str(no_of_projects)+" & "+get_code_generating_models_project(conn,table,where_cond)+"\\\\")
    print("=================================================")

    slc_r_2020b_database = ""
    tables = ['Tutorial','GitHub','MATC','Sourceforge','Others']
    # create a database connection
    conn = create_connection(slc_r_2020b_database)

    for table in tables:
        total_project_id_sql = "Select count(distinct FILE_ID) from "+table+"_models"
        total_project_id = get_all_vals_from_table(conn,total_project_id_sql)
        print(table+" & "+str(total_project_id)+" & "+get_code_generating_models_project(conn,table)+"\\\\")
    print("=================================================")


    slnet_2020b_database = ""
    tables = ['GitHub','MATC']
    # create a database connection
    conn = create_connection(slnet_2020b_database)
    for table in tables:
        total_project_id_sql = "Select count(distinct FILE_ID) from "+table+"_models"
        total_project_id = get_all_vals_from_table(conn,total_project_id_sql)
        print(table+" & "+str(total_project_id)+" & "+get_code_generating_models_project(conn,table)+"\\\\")




if __name__ == '__main__':
    main()


