import logging
import sqlite3
import pandas as pd
from sqlite3 import Error
from statistics import variance, stdev

def get_all_vals_from_table(conn,sql):
    cur = conn.cursor()
    cur.execute(sql)
    rows = cur.fetchall()
    results = [r[0] for r in rows]

    return results

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
def calculate_reuse_rate(s_funcs_per_model):
    
    s_funcs = s_funcs_per_model.split(',')
    total_sfunc = 0
    reused_sfunc = 0
    for s_func in s_funcs:
        s_func = s_func.strip()
        if s_func == '':
            continue
        name, count = s_func.rsplit('_',1)
        total_sfunc += float(count)
        reused_sfunc += float(count) - 1

    return reused_sfunc/total_sfunc

def get_median(list_of_vals):
    n = len(list_of_vals)
    if n % 2 == 0:
        median1 = list_of_vals[n // 2]
        median2 = list_of_vals[n // 2 - 1]
        median = (median1 + median2) / 2
    else:
        median = list_of_vals[n // 2]
    return median
    

def calculate_quartiles(list_of_vals):
    '''
    args:
        list_of_vals : sorted list
    '''
    list_of_vals.sort()
    sum_list = sum(list_of_vals)
    n = len(list_of_vals)
    
    mean = sum_list/n
    
    middle = n//2

    median = get_median(list_of_vals)
    lower_quartile = get_median(list_of_vals[:middle])
    upper_quartile = get_median(list_of_vals[middle:])
    
    return [round(list_of_vals[0],2),round(lower_quartile,2),round(median,2),round(upper_quartile,2),round(list_of_vals[n-1],2),round(mean,2)]

def convert_df_to_str(df):
	res =""
	for name in df:
		if(not pd.isna(name)):

			res+='"'+name[:-1]+'"'+','
	res = res[:-1]
	return res

def get_s_function_reuse_rate(conn,table, where_cond = None):
    s_functions_sql = "Select sfun_nam_count from "+table+"_models where sfun_nam_count not in ('','N/A')"
   

    if where_cond is not None: 
        s_functions_sql += where_cond
    s_functions = get_all_vals_from_table(conn,s_functions_sql)
   
    s_func_reuse_rate = []
    for s_function in s_functions:
        result = calculate_reuse_rate(s_function)
        s_func_reuse_rate.append(result)
        #print('{} : {}'.format(s_function,result))
    return s_func_reuse_rate
    

def main():

    print("Min  Lower-Quartile median upper_quartile max Avg")
    
    df = pd.read_csv('slcorpus-0.csv')

    mdl_names = convert_df_to_str(df["Tutorial"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Simple"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Advanced"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Others"])

    extra_where_cond = "and substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ")"
    
    slc_r_2017a_database = ""
    tables = ['Tutorial','GitHub','MATC','Sourceforge','Others']
    # create a database connection
    conn = create_connection(slc_r_2017a_database)
    all_reuse_rates = []
    for table in tables:
        all_reuse_rates.extend(get_s_function_reuse_rate(conn,table,extra_where_cond))
    ans = calculate_quartiles(all_reuse_rates)
    print(ans)
    print("&".join(map(str,ans)))
    print("=================================================")

    slc_r_2020b_database = ""
    tables = ['Tutorial','GitHub','MATC','Sourceforge','Others']
    # create a database connection
    conn = create_connection(slc_r_2020b_database)
    all_reuse_rates = []
    for table in tables:
        all_reuse_rates.extend(get_s_function_reuse_rate(conn,table,extra_where_cond))
    ans = calculate_quartiles(all_reuse_rates)
    print(ans)
    print("&".join(map(str,ans)))
    print("=================================================")

    
    slc_20r_2020b_database = ""
    tables = ["All"]
    # create a database connection
    conn = create_connection(slc_20r_2020b_database)
    all_reuse_rates = []
    for table in tables:
        all_reuse_rates.extend(get_s_function_reuse_rate(conn,table))
    ans = calculate_quartiles(all_reuse_rates)
    print(ans)
    print("&".join(map(str,ans)))
    print("=================================================")
    
    slnet_2020b_database = ""
    tables = ['GitHub','MATC']
    # create a database connection
    conn = create_connection(slnet_2020b_database)
    all_reuse_rates = []
    for table in tables:
        all_reuse_rates.extend(get_s_function_reuse_rate(conn,table))
    ans = calculate_quartiles(all_reuse_rates)
    print(ans)
    print("&".join(map(str,ans)))
    print("=================================================")


    

if __name__ == '__main__':
    main()

    #calculate_reuse_rate(',scominttobit_1,sdspmultiportsel_1,sfix_udelay_1,sdspfilter2_2,sdspsreg2_1')
