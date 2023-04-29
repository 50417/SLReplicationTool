import pandas as pd
import numpy as np
import matplotlib
import matplotlib.ticker as mtick
import matplotlib.pyplot as plt
"""matplotlib.use("pgf")"""
matplotlib.rcParams.update({
    'font.family': 'Times New Roman',
    'font.size' : 14,

})
from analyzeProjects import create_connection

def abbreviate_names(blk_types,name_abbr):
    n = len(blk_types)
    for i in range(0, n):
        if(blk_types[i] in name_abbr):
            blk_types[i] = name_abbr[blk_types[i]]

    return blk_types

def get_frequentlyusedBlocks_slnet(conn):
    cur = conn.cursor()
    sql = "Select b1,c1+c2 num_of_models from " \
      "(select BLK_TYPE b1,count(*)  as c1 from GitHub_Blocks group by BLK_TYPE) " \
      "Join (select BLK_TYPE b2 ,count(*) as c2 from Matc_Blocks group by BLK_TYPE ) " \
      "on b1=b2 " \
      "order by num_of_models desc"
    cur.execute(sql)
    rows = cur.fetchall()
    blk_types = []
    number_of_model_used_in = []
    for i in range(0,60):
        blk_types.append(rows[i][0])
        number_of_model_used_in.append(rows[i][1])
    return blk_types, number_of_model_used_in

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



def get_slc2_blk_mdl_cnt(conn):
    df = pd.read_csv('slcorpus-0.csv')

    mdl_names = convert_df_to_str(df["Tutorial"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Simple"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Advanced"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Others"])

    most_freq_blks,no_of_model,slc2_blk_mdlcnt = get_frequentlyusedBlocks_slc2(conn,mdl_names)
    
    return most_freq_blks,no_of_model,slc2_blk_mdlcnt 

def get_slnet_blk_mdl_cnt(conn):
    slnet_blk_cnt = {}
    most_freq_blks,no_of_model = get_frequentlyusedBlocks_slnet(conn)
    # Some of Simulink builtin library blocks is a Subsystem. So distinguishing  user created subsystem  and builtin blocks to only include models that has user created subsystem in the plot 
    mat_subsystem_gt_zero = "Select Agg_SubSystem_count from matc_models where Agg_SubSystem_count>0 order by Agg_SubSystem_count"
    git_subsystem_gt_zero = "Select Agg_SubSystem_count from github_models where Agg_SubSystem_count>0 order by Agg_SubSystem_count"
    subsystem_gt_zero = get_all_vals_from_table(conn, git_subsystem_gt_zero,mat_subsystem_gt_zero)
    total_gt_zero_subsystem_models = len(subsystem_gt_zero)

    for i in range(len(most_freq_blks)):
        if most_freq_blks[i] == 'SubSystem':
            
            no_of_model[i] = total_gt_zero_subsystem_models
            break
    
    github_non_lib = "select id from github_models where is_lib = 0 and is_test = -1"
    matc_non_lib = "select id from matc_models where is_lib = 0 and is_test = -1"
    total_non_lib_models = get_all_vals_from_table(conn, github_non_lib,matc_non_lib)
    non_lib_models = len(total_non_lib_models)
    

     

    for i in range(len(most_freq_blks)):
        slnet_blk_cnt[most_freq_blks[i]] = no_of_model[i]/non_lib_models*100
        #print(most_freq_blks[i], no_of_model[i] )
    no_of_model = [x/non_lib_models*100 for x in no_of_model]
    #print(no_of_model)
    return most_freq_blks, no_of_model, slnet_blk_cnt

def convert_df_to_str(df):
    res =""
    for name in df:
        if(not pd.isna(name)):

            res+='"'+name[:-1]+'"'+','
    res = res[:-1]
    return res

def get_frequentlyusedBlocks_slc2(conn, mdl_names):
    cur = conn.cursor()

    sql = "Select b1,c1+c2+c3+c4+c5 num_of_models from" \
          "(select BLK_TYPE b1,count(*)  as c1 from GitHub_Blocks where substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ") group by BLK_TYPE) " \
                                                                                                                                          "Join (select BLK_TYPE b2 ,count(*) as c2 from MATC_Blocks where substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ") group by BLK_TYPE) " \
                                                                                                                                                                                                                                                                             "on b1=b2 " \
                                                                                                                                                                                                                                                                             "JOIN" \
                                                                                                                                                                                                                                                                             "(select BLK_TYPE b3,count(*)  as c3 from others_Blocks where substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ") group by BLK_TYPE) " \
                                                                                                                                                                                                                                                                                                                                                                                                             "on b1 = b3 " \
                                                                                                                                                                                                                                                                                                                                                                                                             " JOIN " \
                                                                                                                                                                                                                                                                                                                                                                                                             "(select BLK_TYPE b4,count(*)  as c4 from Tutorial_Blocks where substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ") group by BLK_TYPE)" \
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               "on b1 = b4" \
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               " JOIN " \
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               "(select BLK_TYPE b5,count(*)  as c5 from sourceForge_Blocks where substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + ") group by BLK_TYPE) " \
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    "on b1 = b5 " \
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    "order by num_of_models desc"
    #print(sql)
    cur.execute(sql)
    rows = cur.fetchall()
    blk_types = []
    number_of_model_used_in = []

    tables = ["github", "matc", "tutorial", "sourceforge", "others"]
    subsys_sql = "select "
    for t in tables:
        subsys_sql += "(select count(*) from " + t + "_models where is_lib =0 and is_test = -1 and Agg_SubSystem_count>0 " \
                                                     "and  substr(Model_Name,0,length(Model_name)-3) IN (" + mdl_names + "))"
        if t != "others":
            subsys_sql += "+"
    #print(subsys_sql)
    cur.execute(subsys_sql)
    subsys_rows = cur.fetchall()

 
    slc2_blk_mdlcnt = {}
    non_lib_models = 1117

    for i in range(32):
        if rows[i][0] == 'SubSystem':
            blk_types.append(rows[i][0])
            
            number_of_model_used_in.append(subsys_rows[0][0]/non_lib_models*100)
            slc2_blk_mdlcnt[rows[i][0]] = subsys_rows[0][0]/non_lib_models*100
        else:
            blk_types.append(rows[i][0])
            number_of_model_used_in.append(rows[i][1]/non_lib_models*100)
            slc2_blk_mdlcnt[rows[i][0]] = rows[i][1]/non_lib_models*100
    return blk_types, number_of_model_used_in, slc2_blk_mdlcnt

def plot_combined_blk_type(x,y1,y2,xlabel=None, ylabel=None,figurename = None,xtickRot=None,abbr=None,firstmarker='o',secondmarker='x'):
    ax = plt.subplot()
    ax.plot(x,y1,marker=firstmarker,linestyle="None",markerfacecolor='None',
            markeredgecolor='black')
    ax.plot(x,y2,marker=secondmarker,linestyle="None",markerfacecolor='None',
            markeredgecolor='black')
    plt.xticks(rotation = xtickRot)
    ax.set_yticks(np.arange(0,90,10))
    ax.yaxis.set_major_formatter(mtick.PercentFormatter())
    if xlabel is not None:
        plt.xlabel(xlabel)
    textstr = ""
    if abbr is not None:
        for k,v in abbr.items():
            textstr += v + " : " + k +"\n"
        textstr = textstr[:len(textstr)-1]
        props = dict(boxstyle='round', facecolor='white', alpha=0.5)
        ax.text(0.4, 0.95, textstr, transform=ax.transAxes, fontsize=12,
        verticalalignment='top', bbox=props)
        figure = plt.gcf()
        figure.set_size_inches(6.5, 2.5)

    plt.ylabel(ylabel)

    plt.savefig(figurename,bbox_inches='tight')
    plt.show()
    plt.close()

def main():
    slnet_database = ""
    # SC R database
    slc2_database = ""

    slnet_conn = create_connection(slnet_database)
    slnet_blk_type, slnet_model_ratio, slnet_blk_mdlratio = get_slnet_blk_mdl_cnt(slnet_conn)
    #print(slnet_blk_cnt, total_non_lib_models)

    slc2_conn = create_connection(slc2_database)
    slc2_blk_type, slc2_model_ratio, slc2_blk_mdlratio = get_slc2_blk_mdl_cnt(slc2_conn)
    

    #GET model ratio based on top 25 frequently used in slc2 models
    slnet_mdl_cnt_lst = []


    for i in range(25):
        slnet_mdl_cnt_lst.append(slnet_blk_mdlratio[slc2_blk_type[i]])
    slc2_model_ratio = slc2_model_ratio[:25]

    name_abbr = {"DataTypeConversion": "DT-Conv", "ToWorkspace": "ToW",
             "MultiPortSwitch": "MultiPort","DiscretePulseGenerator":"DiscGen","ManualSwitch":"ManSwitch"}
    slc2_blk_type = abbreviate_names(slc2_blk_type,name_abbr)
    slc2_blk_type = slc2_blk_type[:25]

    plot_combined_blk_type(slc2_blk_type,slc2_model_ratio, slnet_mdl_cnt_lst, ylabel="Model Ratio", figurename="combined_most_freq_blks.pdf",xtickRot=90,abbr = name_abbr)
   
    #GET model ratio of slc2 based on top 25 frequently used in slnet models
    slc2_mdl_cnt_lst = []


    for i in range(25):
        if slnet_blk_type[i] in slc2_blk_mdlratio:
            slc2_mdl_cnt_lst.append(slc2_blk_mdlratio[slnet_blk_type[i]])
        else:
            slc2_mdl_cnt_lst.append(0)
    slnet_model_ratio = slnet_model_ratio[:25]
 
    name_abbr = {"DataTypeConversion": "DT-Conv", "PMComponent": "PMComp", "ToWorkspace": "ToW",
                 "RelationalOperator": "RelOp"}
    
    slnet_blk_type = abbreviate_names(slnet_blk_type,name_abbr)
    slnet_blk_type = slnet_blk_type[:25]

    plot_combined_blk_type(slnet_blk_type,slnet_model_ratio, slc2_mdl_cnt_lst, ylabel="Model Ratio", figurename="combined_most_freq_blks_slnetmfub.pdf",xtickRot=90,abbr = name_abbr,firstmarker='x',secondmarker='o')

    

if __name__ == '__main__':
    main()
