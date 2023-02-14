import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import numpy
"""matplotlib.use("pgf")"""
matplotlib.rcParams.update({
    'font.family': 'Times New Roman',
    'font.size' : 14,

})
from analyzeProjects import create_connection
def convert_df_to_str(df):
    res =""
    for name in df:
        if(not pd.isna(name)):

            res+='"'+name[:-1]+'"'+','
    res = res[:-1]
    return res
    #pd.isna(df)


def get_frequentlyusedBlocks(conn, mdl_names):
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
    for i in range(0, 25):
        if rows[i][0] == 'SubSystem':
            blk_types.append(rows[i][0])
            number_of_model_used_in.append(subsys_rows[0][0])
        else:
            blk_types.append(rows[i][0])
            number_of_model_used_in.append(rows[i][1])
    return blk_types, number_of_model_used_in
def abbreviate_names(blk_types,name_abbr):
    n = len(blk_types)
    for i in range(0, n):
        if(blk_types[i] in name_abbr):
            blk_types[i] = name_abbr[blk_types[i]]

    return blk_types


def plot(x,y,xlabel=None, ylabel=None,figurename = None,xtickRot=None,abbr=None):
    ax = plt.subplot()
    ax.bar(x,y,color ='white',edgecolor='black')
    plt.xticks(rotation = xtickRot)
    if xlabel is not None:
        plt.xlabel(xlabel)
    textstr = ""

    if abbr is not None:
        for k,v in abbr.items():
            textstr += v + " : " + k +"\n"
        props = dict(boxstyle='round', facecolor='white', alpha=0.5)
        ax.text(0.4, 0.95, textstr, transform=ax.transAxes, fontsize=12,
        verticalalignment='top', bbox=props)
        plt.yticks(numpy.arange(0, max(y), 100))
        plt.grid(True, axis='y')
        figure = plt.gcf()
        figure.set_size_inches(6.5, 2.5)

    plt.ylabel(ylabel)

    plt.savefig(figurename,bbox_inches='tight')
    #plt.show()
    plt.close()
def main():
    SlCorpus2_exclude_lib_database = ""
    # create a database connection
    conn = create_connection(SlCorpus2_exclude_lib_database)
    df = pd.read_csv('slcorpus-0.csv')

    mdl_names = convert_df_to_str(df["Tutorial"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Simple"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Advanced"])
    mdl_names =mdl_names + ","+convert_df_to_str(df["Others"])

    most_freq_blks,no_of_model = get_frequentlyusedBlocks(conn,mdl_names)
    #print(most_freq_blks)
    #print(no_of_model)
    name_abbr = {"DataTypeConversion": "DT-Conv", "ToWorkspace": "ToW",
             "MultiPortSwitch": "MultiPort","DiscretePulseGenerator":"DiscGen","ManualSwitch":"ManSwitch"}

    most_freq_blks = abbreviate_names(most_freq_blks,name_abbr)
    plot(most_freq_blks,no_of_model, ylabel="Number of Models", figurename="sl_corpus_2_most_freq_blks.pdf",xtickRot=90,abbr = name_abbr)


main()
	  
