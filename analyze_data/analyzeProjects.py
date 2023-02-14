import logging
import sqlite3
from sqlite3 import Error
import time
from datetime import datetime
from statistics import variance, stdev
logging.basicConfig(filename='analyze_projects.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)

#logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
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

def get_commits(conn,project=True):
    '''
    returns number of commits per project or model in a list
    '''
    cur = conn.cursor()
    if project:
        table = 'GitHub_Projects_Commit_Info'
    else:
        table = 'GitHub_Model_Commit_Info'
    cur.execute("Select total_number_of_commits from "+table+" order by total_number_of_commits")

    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_merge_commits_projects(conn):
    cur = conn.cursor()
    cur.execute("select cast(Number_of_merge_commits as float)/cast(Total_number_of_commits as float)*100 per from github_projects_commit_info order by per")

    rows = cur.fetchall()
    return [r[0] for r in rows]

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

    return str(round(list_of_vals[0],2))+"\t&"+str(round(list_of_vals[n-1],2))+"\t&"+str(round(mean,2))+\
           "\t&"+str(round(median,2))+"\t&"+str(round(stdev(list_of_vals),2))

def get_number_of_authors(conn, project = True):
    '''
    returns number of authors per project or model in a list
    '''
    cur = conn.cursor()
    if project:
        table = 'GitHub_Projects_Commit_Info'
    else:
        table = 'GitHub_Model_Commit_Info'
    cur.execute("Select number_of_authors from " + table + " order by number_of_authors")

    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_lifetime(conn, project = True):
    '''
    returns absolute lifetime of project or model(days) in a list
    '''
    cur = conn.cursor()
    if project:
        sql ="select LifeTime_in_days from github_projects_commit_info order by LifeTime_in_days"
    else:
        sql = "select Abs_lifeTime_in_days from GitHub_Model_Commit_Info order by Abs_lifeTime_in_days"
    cur.execute(sql)

    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_commit_per_day(conn):
    cur = conn.cursor()

    sql = "select Commit_per_day from GitHub_Projects_Commit_Info order by Commit_per_day"
    cur.execute(sql)

    rows = cur.fetchall()
    return [r[0] for r in rows]

def convert_rows_to_set(rows):
    res = set()
    for r in rows:
        res.add(r[0])
    return res

def get_model_author_per(conn):
    model_author_per = []
    cur = conn.cursor()

    project_ids_sql  = "select id from github_projects_commit_info"
    cur.execute(project_ids_sql)
    rows = cur.fetchall()
    project_ids = [r[0] for r in rows]
    for id in project_ids:
        model_author_sql = "select author_email from Model_commits where id = " + str(id)
        cur.execute(model_author_sql)
        model_author_set = convert_rows_to_set(cur.fetchall())

        project_author_sql = "select author_email from Project_commits where id = " + str(id)
        cur.execute(project_author_sql)
        project_author_set = convert_rows_to_set(cur.fetchall())

        model_author_per.append(len(model_author_set)/len(project_author_set)*100)
        #print(model_commits_per)
    return sorted(model_author_per)

def get_model_commits_per(conn):
    model_commits_per = []
    cur = conn.cursor()

    project_ids_sql  = "select id from github_projects_commit_info"
    cur.execute(project_ids_sql)
    rows = cur.fetchall()
    project_ids = [r[0] for r in rows]
    for id in project_ids:
        model_hash_sql = "select hash from Model_commits where id = " + str(id)
        cur.execute(model_hash_sql)
        model_hash_set = convert_rows_to_set(cur.fetchall())

        project_hash_sql = "select hash from Project_commits where id = " + str(id)
        cur.execute(project_hash_sql)
        project_hash_set = convert_rows_to_set(cur.fetchall())
        if len(model_hash_set) == 0 :
            print("jere")
        model_commits_per.append(len(model_hash_set)/len(project_hash_set)*100)
        #print(model_commits_per)
    return sorted(model_commits_per)


def get_model_updates(conn):
    model_update = "select updates from(select  id,model_name, sum(modifications) updates from Model_commits group by id, model_name order by updates)"
    cur = conn.cursor()

    cur.execute(model_update)
    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_model_authors(conn):
    model_author = "select Number_of_authors from GitHub_Model_Commit_Info order by Number_of_authors"
    cur = conn.cursor()

    cur.execute(model_author)
    rows = cur.fetchall()
    return [r[0] for r in rows]
def get_model_abs_lifetime(conn):
    model_lt = "select abs_lifetime_in_days from GitHub_Model_Commit_Info order by abs_lifetime_in_days"
    cur = conn.cursor()

    cur.execute(model_lt)
    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_model_abs_lifetime_meta(conn):
    model_lt = "select last_modified, created_date from model_meta where last_modified !='' and created_date !=''"
    cur = conn.cursor()

    cur.execute(model_lt)
    rows = cur.fetchall()
    last_m = []
    creat_m = []
    res = []
    for r in rows:
        print(r[0])
        print(r[1])
        try:
            ans = datetime.strptime(r[0], '%c') -datetime.strptime(r[1], '%c')
        except Exception as e:
            continue

        ans_in_days = ans.days + ans.seconds/86400
        assert(ans_in_days>=0)
        print(ans_in_days)
        res.append(ans_in_days)

    return res

def get_all_vals_from_table(conn,gsql , msql):
    cur = conn.cursor()
    cur.execute(gsql)
    rows = cur.fetchall()
    g_results = [r[0] for r in rows]

    cur.execute(msql)
    rows = cur.fetchall()
    m_results = [r[0] for r in rows]

    res = g_results + m_results
    res.sort()
    return res

def get_code_generating_models_project(conn):
    mat_embedded = "select count(distinct FILE_ID) from Matc_code_gen where System_Target_File in  ('ert.tlc','ert_shrlib.tlc') and Solver_Type =='Fixed-step' "
    git_embedded = 'select count(distinct FILE_ID) from github_code_gen where System_Target_File in  ("ert.tlc","ert_shrlib.tlc") and Solver_Type =="Fixed-step" '
    embedded = get_all_vals_from_table(conn,git_embedded,mat_embedded)
    print(" Project with models configured to generate code using Embedded Coder ")
    print("GitHub : {}".format(embedded[0] ))
    print("MATLAB Central: {}".format(embedded[1] ))

    mat_others = ' select count(distinct FILE_ID) from matc_code_gen where System_Target_File not in  ("ert.tlc","ert_shrlib.tlc") and (System_Target_File in ("rsim.tlc","rtwsun.tlc")  or Solver_Type =="Fixed-step") '
    git_others = ' select count(distinct FILE_ID) from github_code_gen where System_Target_File not in  ("ert.tlc","ert_shrlib.tlc") and (System_Target_File in ("rsim.tlc","rtwsun.tlc")  or Solver_Type =="Fixed-step")  '
    others = get_all_vals_from_table(conn,git_others,mat_others)
    print(" Project with models configured to generate code using toolbox other than Embedded Coder ")
    print("GitHub : {}".format(others[0] ))
    print("MATLAB Central: {}".format(others[1] ))

    mat_total = '  select count(distinct FILE_ID) from Matc_code_gen where System_Target_File in  ("rsim.tlc","rtwsun.tlc")  or ( System_Target_File not in  ("rsim.tlc","rtwsun.tlc") and Solver_Type =="Fixed-step")'
    git_total = '  select count(distinct FILE_ID) from github_code_gen where System_Target_File in  ("rsim.tlc","rtwsun.tlc")  or ( System_Target_File not in  ("rsim.tlc","rtwsun.tlc") and Solver_Type =="Fixed-step")'
    total = get_all_vals_from_table(conn,git_total,mat_total)
    print(" Project with models configured to generate code using Embedded Coder ")
    print("GitHub : {}".format(total[0] ))
    print("MATLAB Central: {}".format(total[1] ))

def get_model_rel_lifetime(conn):
    model_rl = "select relative_lifetime*100 from GitHub_Model_Commit_Info order by relative_lifetime"
    cur = conn.cursor()

    cur.execute(model_rl)
    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_commits_info(conn):
    lifetime_over50 = "select total_number_of_commits from GitHub_Projects_Commit_Info where total_number_of_commits<50"
    cur = conn.cursor()

    cur.execute(lifetime_over50)
    rows = cur.fetchall()
    lifetime = [r[0] for r in rows]
    print("Percentage of projects less than 50 : {}".format(len(lifetime)/200))


#sql = "select cast(Model_commits as float)/cast(Total_number_of_commits as float)*100 per from github_projects_commit_info order by per"

def main():
    start = time.time()
    database = ""

    # create a database connection
    conn = create_connection(database)
    print("Project level metrics")
    print("Project Metric & Min. & Max. & Mean& Median & Std. Dev")
    print(get_commits(conn)[109])
    print(get_commits(conn)[110])
    print(len(get_commits(conn)))
    no_of_commits  = calculate_quartiles(get_commits(conn))
    print("Number of commits &"+ no_of_commits)
    merge_percent = calculate_quartiles(get_merge_commits_projects(conn))
    print("Merge commits in %&" + merge_percent)
    number_of_authors = calculate_quartiles(get_number_of_authors(conn))
    print("Number of authors&" + number_of_authors)
    lifetime_in_days = calculate_quartiles(get_lifetime(conn))
    print("Lifetime in days&" + lifetime_in_days)
    commit_per_day= calculate_quartiles(get_commit_per_day(conn))
    print("Commit per day&" + commit_per_day)
    model_commits_per = calculate_quartiles(get_model_commits_per(conn))
    print("Model commits in %&"+ model_commits_per)
    model_author_per = calculate_quartiles(get_model_author_per(conn))
    print("Model authors in %&"+ model_author_per)

    # Model Metrics
    print("Model level metrics")
    model_update = calculate_quartiles(get_model_updates(conn))
    print("Number of updates &"+model_update)
    model_update = calculate_quartiles(get_model_authors(conn))
    print("Number of authors &" + model_update)
    model_lifetime = calculate_quartiles(get_model_abs_lifetime(conn))
    print("Abs lifetime in days &" + model_lifetime)
    model_rel_lifetime = calculate_quartiles(get_model_rel_lifetime(conn))
    print("Relative lifetime in % &" + model_rel_lifetime)
    get_commits_info(conn)
    
    print('====================')
    get_code_generating_models_project(conn)




if __name__ == '__main__':
    main()
