import logging
import numpy
from datetime import datetime
from analyzeProjects import calculate_quartiles
import matplotlib
import matplotlib.pyplot as plt
"""matplotlib.use("pgf")"""
matplotlib.rcParams.update({
    'font.family': 'Times New Roman',
    'font.size' : 14,

})
from analyzeProjects import create_connection
logging.basicConfig(filename='SLNET_plots.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)
def get_domain_counts(conn,domain):
    cur = conn.cursor()
    gitsql = "select count(*) c1 from matc_projects where lower(category) like '%" + domain + "%'"
    matcsql = "select count(*) c1 from github_projects where lower(topics) like '%" +domain +"%' or lower(topics) like '%" +domain +"%'"
    cur.execute(gitsql)
    rows = cur.fetchall()
    git_count = int(rows[0][0])

    cur.execute(matcsql)
    rows = cur.fetchall()
    matc_count = int(rows[0][0])
    return git_count + matc_count

def get_most_domain_counts(conn):
    cur = conn.cursor()
    gitsql = "select lower(category) from matc_projects"
    matcsql = "select lower(topics) from github_projects"
    cur.execute(gitsql)
    rows = cur.fetchall()
    category_cnt = {}
    for r in rows:
        list_of_category = r[0].split(",")
        for category in list_of_category:
            if category not in category_cnt:
                category_cnt[category] = 1
            category_cnt[category] += 1

    cur.execute(matcsql)
    rows = cur.fetchall()
    for r in rows:
        list_of_category = r[0].split(",")
        for category in list_of_category:
            if category not in category_cnt:
                category_cnt[category] = 1
            category_cnt[category] += 1
    val = sorted(category_cnt, key = category_cnt.get,reverse=True)

def get_frequentlyusedBlocks(conn):
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
    for i in range(0,25):
        blk_types.append(rows[i][0])
        number_of_model_used_in.append(rows[i][1])
    return blk_types, number_of_model_used_in

def get_open_issues(conn):
    open_issues = "select open_issues_count from GitHub_Projects order by open_issues_count"
    cur = conn.cursor()

    cur.execute(open_issues)
    rows = cur.fetchall()
    return [r[0] for r in rows]

def get_matc_projects_meta(conn):
    cur = conn.cursor()
    comments_sql = "select no_of_comments from matc_projects"
    ratings_sql = "select no_of_ratings from matc_projects"
    average_ratings_sql = "select average_rating from matc_projects"

    cur.execute(comments_sql)
    rows = cur.fetchall()
    comments = [r[0] for r in rows]

    cur.execute(ratings_sql)
    rows = cur.fetchall()
    ratings = [r[0] for r in rows]

    cur.execute(average_ratings_sql)
    rows = cur.fetchall()
    average_ratings = [r[0] for r in rows]

    return comments, ratings, average_ratings


def get_git_projects_meta(conn):
    cur = conn.cursor()
    # Watcher is same as Stargazers Due to a naming convention change https://github.community/t/bug-watchers-count-is-the-duplicate-of-stargazers-count/140865/4
    #watchers_sql = "select watchers_count from github_projects"
    forks_sql = "select forks_count from github_projects"
    open_issues_sql = "select open_issues_count from github_projects"
    stargazers_sql = "select stargazers_count from github_projects"


    cur.execute(forks_sql)
    rows = cur.fetchall()
    forks = [r[0] for r in rows]

    cur.execute(open_issues_sql)
    rows = cur.fetchall()
    open_issues = [r[0] for r in rows]

    cur.execute(stargazers_sql)
    rows = cur.fetchall()
    stargazers = [r[0] for r in rows]

    return forks , open_issues,stargazers



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
        ax.text(0.45, 0.95, textstr, transform=ax.transAxes, fontsize=12,
        verticalalignment='top', bbox=props)
        figure = plt.gcf()
        figure.set_size_inches(6.5, 2.5)

    plt.ylabel(ylabel)

    plt.savefig(figurename,bbox_inches='tight')
    #plt.show()
    plt.close()


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

def get_metrics_on_project_size(conn):
    g_nummdl_sql = " select num_model_file from github_projects order by num_model_file"
    m_nummdl_sql = "select num_model_file from Matc_projects order by num_model_file"
    num_mdl = get_all_vals_from_table(conn,g_nummdl_sql,m_nummdl_sql)

    git_project_blks = "select s from ( select File_id,sum(SCHK_Block_count) s from github_models where SCHK_Block_count>-1 group by File_id )where s >-1 order by s"
    mat_project_blks = "select s from ( select File_id,sum(SCHK_Block_count) s from matc_models where SCHK_Block_count>-1 group by File_id )where s >-1 order by s"
    project_blks = get_all_vals_from_table(conn,git_project_blks,mat_project_blks)

    git_mdl_blks = "select SCHK_Block_count from github_models where SCHK_Block_count>-1 order by SCHK_Block_count"
    mat_mdl_blks = "select SCHK_Block_count from matc_models where SCHK_Block_count>-1 order by SCHK_Block_count"
    mdl_blks = get_all_vals_from_table(conn, git_mdl_blks,mat_mdl_blks)


    git_prj_blk_types = "select b from( select File_id,count(DISTINCT BLK_TYPE) b from GitHub_Blocks group by File_id ) order by b"
    mat_prj_blk_types = "select b from( select File_id,count(DISTINCT BLK_TYPE) b from Matc_Blocks group by File_id ) order by b"
    prj_blk_types = get_all_vals_from_table(conn, git_prj_blk_types, mat_prj_blk_types)
    for i in range(len(project_blks)- len(prj_blk_types)):
        prj_blk_types.append(0)
    prj_blk_types.sort()

    git_mdl_blk_types = "select b from( select File_id,Model_Name, count(DISTINCT BLK_TYPE) b from GitHub_Blocks group by File_id,Model_Name ) order by b"
    mat_mdl_blk_types = "select b from( select File_id,Model_Name, count(DISTINCT BLK_TYPE) b from Matc_Blocks group by File_id,Model_Name ) order by b"
    mdl_blk_types = get_all_vals_from_table(conn,git_mdl_blk_types,mat_mdl_blk_types )
    for i in range(len(mdl_blks)- len(mdl_blk_types)):
        mdl_blk_types.append(0)
    mdl_blk_types.sort()

    git_prj_signal_lines ="select s from ( select File_id,sum(total_ConnH_cnt) s from github_models where total_ConnH_cnt>-1 group by File_id )where s >-1 order by s"
    mat_prj_signal_lines = "select s from ( select File_id,sum(total_ConnH_cnt) s from matc_models where total_ConnH_cnt>-1 group by File_id )where s >-1 order by s"
    prj_signal_lines = get_all_vals_from_table(conn, git_prj_signal_lines, mat_prj_signal_lines)

    git_mdl_signal_lines = "select total_ConnH_cnt from github_models where total_ConnH_cnt >-1 order by total_ConnH_cnt"
    mat_mdl_signal_lines = "select total_ConnH_cnt from matc_models where total_ConnH_cnt >-1 order by total_ConnH_cnt"
    mdl_signal_lines  = get_all_vals_from_table(conn, git_mdl_signal_lines,mat_mdl_signal_lines)

    git_prj_subsys = "select s from ( select File_id,sum(Agg_SubSystem_count) s from github_models where Agg_SubSystem_count>-1 group by File_id )where s >-1 order by s"
    mat_prj_subsys = "select s from ( select File_id,sum(Agg_SubSystem_count) s from matc_models where Agg_SubSystem_count>-1 group by File_id )where s >-1 order by s"
    prj_subsys = get_all_vals_from_table(conn, git_prj_subsys,mat_prj_subsys)

    git_mdl_subsys = "select Agg_SubSystem_count from github_models where Agg_SubSystem_count>-1 order by Agg_SubSystem_count"
    mat_mdl_subsys = "select Agg_SubSystem_count from matc_models where Agg_SubSystem_count>-1 order by Agg_SubSystem_count"
    mdl_subsys = get_all_vals_from_table(conn, git_mdl_subsys, mat_mdl_subsys)

    git_prj_cyclo = "select s from ( select File_id,sum(CComplexity) s from github_models where CComplexity>-1 group by File_id )where s >-1 order by s"
    mat_prj_cyclo = "select s from ( select File_id,sum(CComplexity) s from matc_models where CComplexity>-1 group by File_id )where s >-1 order by s"
    prj_cyclo = get_all_vals_from_table(conn, git_prj_cyclo,mat_prj_cyclo)

    git_mdl_cyclo = "select CComplexity from github_models where CComplexity>-1 order by CComplexity"
    mat_mdl_cyclo = "select CComplexity from matc_models where CComplexity>-1 order by CComplexity"
    mdl_cyclo = get_all_vals_from_table(conn, git_mdl_cyclo,mat_mdl_cyclo)

    return num_mdl,project_blks,mdl_blks,prj_blk_types,mdl_blk_types,prj_signal_lines,mdl_signal_lines,prj_subsys,mdl_subsys,prj_cyclo,mdl_cyclo

def abbreviate_names(blk_types,name_abbr):
    n = len(blk_types)
    for i in range(0, n):
        if(blk_types[i] in name_abbr):
            blk_types[i] = name_abbr[blk_types[i]]

    return blk_types


def get_average_lines_per_block(conn,mat_linesperblock,git_linesperblock):
    cur = conn.cursor()
    g_results = []
    cur.execute(git_linesperblock)
    rows = cur.fetchall()

    g_results = [r[1]/r[0] for r in rows]

    cur.execute(mat_linesperblock)
    rows = cur.fetchall()
    m_results = [r[1]/r[0] for r in rows]

    res = g_results + m_results
    average_lines_per_block = (sum(res)/len(res))
    max_value = max(res)
    min_value = min(res)
    print("Min  Signal Lines per block:" + str(min_value))
    print("Max  Signal Lines per blocks:" + str(max_value))
    arr = numpy.array(res)
    range = average_lines_per_block-min_value
    upper_limit = average_lines_per_block+range
    print("Percentage Simulink Model wth signal lines outside the range{:.2f} : {:.3f}".format(range,len(arr[arr>upper_limit])/len(arr)))

    return average_lines_per_block

def get_block_lt_X(conn,matc_lt_12_blk,git_lt_12_blk,X):
    cur = conn.cursor()
    g_results = 0
    cur.execute(git_lt_12_blk)
    rows = cur.fetchall()

    g_results = rows[0][0]

    cur.execute(matc_lt_12_blk)
    rows = cur.fetchall()
    m_results = rows[0][0]

    res = g_results + m_results
    return res



def get_general_metrics(conn):

    total_projects = 2837
    total_models = 7876#9117
    mat_zero_mdl = "select SCHK_Block_count from matc_models where SCHK_Block_count=0"
    git_zero_mdl = "select SCHK_Block_count from github_models where SCHK_Block_count=0"
    zero_mdl = get_all_vals_from_table(conn,git_zero_mdl,mat_zero_mdl)
    print("Zero Block Models : {}".format( len(zero_mdl)))

    git_single_model = "select file_id from (select File_id,count(*) c  from GitHub_models where is_lib=0  and is_test=-1 GROUP by File_id ) where c=1"
    mat_single_model = "select file_id from (select File_id,count(*) c  from matc_models where is_lib=0  and is_test=-1 GROUP by File_id ) where c=1"
    single_model = get_all_vals_from_table(conn,git_single_model,mat_single_model)
    print("Projects with single model :{} ({})".format(len(single_model),len(single_model)/total_projects))

    git_large_projects = "select c from (select File_id,count(*) c  from GitHub_models where is_lib=0  and is_test=-1 GROUP by File_id ) where c>20 order by c DESC"
    mat_large_projects = "select c from (select File_id,count(*) c  from matc_models where is_lib=0  and is_test=-1 GROUP by File_id)  where c>20 order by c DESC"
    large_projects = get_all_vals_from_table(conn, git_large_projects,mat_large_projects)
    print("{} large projects has {} models ({}) ".format(len(large_projects),sum(large_projects),sum(large_projects)/total_models))

    git_over200 = "select SCHK_Block_count from matc_models where SCHK_Block_count>200"
    mat_over200 = "select SCHK_Block_count from github_models where SCHK_Block_count>200"
    industrial_size200 = get_all_vals_from_table(conn,git_over200,mat_over200)
    print("Number of 200 blocks model :{}".format(len(industrial_size200)))

    git_over2000 = "select SCHK_Block_count from matc_models where SCHK_Block_count>2000"
    mat_over2000 = "select SCHK_Block_count from github_models where SCHK_Block_count>2000"
    industrial_size2000 = get_all_vals_from_table(conn, git_over2000, mat_over2000)
    print("Number of 2000 blocks model :{}".format(len(industrial_size2000)))

    git_linesoverblocks = "Select total_ConnH_cnt from github_models where total_ConnH_cnt>-1 and total_ConnH_cnt>=SCHK_Block_count order by total_ConnH_cnt"
    matc_linesoverblocks = "Select total_ConnH_cnt from matc_models where total_ConnH_cnt>-1 and total_ConnH_cnt>=SCHK_Block_count order by total_ConnH_cnt"
    linesoverblocks = get_all_vals_from_table(conn, git_linesoverblocks,matc_linesoverblocks)
    print("Number of models with lines is greater or equal to Blocks:{}:{}".format(len(linesoverblocks),len(linesoverblocks)/total_models))

    mat_subsystem_zero = "Select Agg_SubSystem_count from matc_models where Agg_SubSystem_count=0 order by Agg_SubSystem_count"
    git_subsystem_zero = "Select Agg_SubSystem_count from github_models where Agg_SubSystem_count=0 order by Agg_SubSystem_count"
    subsystem_zero = get_all_vals_from_table(conn, git_subsystem_zero,mat_subsystem_zero)
    print("Number of  model  with zero subsystems:{}({})".format(len(subsystem_zero),len(subsystem_zero)/total_models))

    mat_subsystem_industrial = "Select Agg_SubSystem_count from matc_models where Agg_SubSystem_count>29 order by Agg_SubSystem_count"
    git_subsystem_industrial = "Select Agg_SubSystem_count from github_models where Agg_SubSystem_count>29 order by Agg_SubSystem_count"
    subsystem_industrial = get_all_vals_from_table(conn, git_subsystem_industrial, mat_subsystem_industrial)
    print(
        "Number of  model  with 29 or more subsystems:{}({})".format(len(subsystem_industrial), len(subsystem_industrial) / total_models))

    mat_subsystem_industrial = "Select Agg_SubSystem_count from matc_models where Agg_SubSystem_count>1000 order by Agg_SubSystem_count"
    git_subsystem_industrial = "Select Agg_SubSystem_count from github_models where Agg_SubSystem_count>1000 order by Agg_SubSystem_count"
    subsystem_industrial = get_all_vals_from_table(conn, git_subsystem_industrial, mat_subsystem_industrial)
    print(
        "Number of  model  with 1000 or more subsystems:{}({})".format(len(subsystem_industrial),
                                                                     len(subsystem_industrial) / total_models))

    mat_cc_zero = "select CComplexity from matc_models where CComplexity=0 order by CComplexity"
    git_cc_zero="select CComplexity from github_models where CComplexity=0 order by CComplexity"
    cc_zero = get_all_vals_from_table(conn, mat_cc_zero, git_cc_zero)
    print(
        "Number of  model  with zero Cyclomatic complexity:{}({})".format(len(cc_zero),
                                                                      len(cc_zero) / total_models))

    mat_cc_zero = "select CComplexity from matc_models where CComplexity>40 order by CComplexity"
    git_cc_zero = "select CComplexity from github_models where CComplexity>40 order by CComplexity"
    cc_zero = get_all_vals_from_table(conn, mat_cc_zero, git_cc_zero)
    print(
        "Number of  model  with 40 or more Cyclomatic complexity:{}({})".format(len(cc_zero),
                                                                          len(cc_zero) / total_models))

    # bug in connection count in model involving model references. To be Fixed in SLNET-Metrics.
    mat_linesperblock = "select schk_block_count,total_ConnH_cnt from matc_models where is_lib = 0 and is_test =-1 and total_ConnH_cnt>0 and unique_mdl_ref_count = 0"
    git_linesperblock = "select schk_block_count,total_ConnH_cnt from github_models where is_lib = 0 and is_test =-1 and total_ConnH_cnt>0 and unique_mdl_ref_count = 0"

    linesperblock = get_average_lines_per_block(conn,mat_linesperblock,git_linesperblock)
    print("Average Lines per block:{:.2f}".format(linesperblock))


    X = 8
    git_lt_12_blk = "select count(*)   from github_models where schk_block_count<"+str(X)
    matc_lt_12_blk ="select count(*)   from matc_models where schk_block_count<"+str(X)
    block_lt_X = get_block_lt_X(conn,matc_lt_12_blk,git_lt_12_blk,X)
    print("Block Count less than %d:%5.2f"%(X,block_lt_X/total_models*100))




def main():
    slnet_database = ""

    # create a database connection
    conn = create_connection(slnet_database)
    domains = ['energy','robotics','biotech','automotive','medical','communications','aerospace','electronics']
    projects_per_domain = []
    get_most_domain_counts(conn)
    open_issues = get_open_issues(conn)
    #fit = powerlaw.Fit(numpy.array(open_issues) + 1, xmin=0, discrete=True)
    #fit.power_law.plot_pdf(color='b', linestyle='--', label='fit ccdf')
    #fit.plot_pdf(color='b')

    #print('alpha= ', fit.power_law.alpha, '  sigma= ', fit.power_law.sigma)
    get_general_metrics(conn)
    print("===================================================================")
    print("Project Size and Organization Data")
    num_mdl,project_blks,mdl_blks,prj_blk_types,mdl_blk_types, prj_signal_lines,\
    mdl_signal_lines,prj_subsys,mdl_subsys,prj_cyclo,mdl_cyclo = get_metrics_on_project_size(conn)
    project_size_metric = [num_mdl,project_blks,mdl_blks,prj_blk_types,mdl_blk_types,prj_signal_lines,\
    mdl_signal_lines,prj_subsys,mdl_subsys,prj_cyclo,mdl_cyclo]
    #print(prj_blk_types)
    cols = ["Models(considers library models)\t\t&", "Blocks\t\t& project\t\t& ","Blocks\t\t& model\t\t&"," Block types\t\t& project\t\t&",
     "Block types \t\t& model\t\t&","Signal lines\t\t& project\t\t&", "Signal lines\t\t& model\t\t&",
     "Subsystems\t\t& project\t\t& ", "Subsystems\t\t& model\t\t&","CC\t\t& project\t\t&",
     "CC\t\t& model&\t\t" ]

    for i in range(len(project_size_metric)):
        print(cols[i]+calculate_quartiles(project_size_metric[i])+"\\\\")
    print("===================================================================")
    print("Project domains and Frequently used blocks(saved in pdf)")

    for domain in domains:
        projects_per_domain.append(get_domain_counts(conn,domain))
    #print("&".join(domains))
    for i in range(len(projects_per_domain)):
        print("{}&{}\\\\".format(domains[i],projects_per_domain[i]))

    plot(domains,projects_per_domain, ylabel="Number of Projects", figurename="domain_in_slnet.pdf",xtickRot=45)
	
    most_freq_blks,no_of_model = get_frequentlyusedBlocks(conn)
    name_abbr = {"DataTypeConversion": "DT-Conv", "PMComponent": "PMComp", "ToWorkspace": "ToW",
                 "RelationalOperator": "RelOp"}
    
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

    most_freq_blks = abbreviate_names(most_freq_blks,name_abbr)
    plot(most_freq_blks,no_of_model, ylabel="Number of Models", figurename="most_freq_blks.pdf",xtickRot=90,abbr = name_abbr)

    comments, ratings, average_ratings = get_matc_projects_meta(conn)
    print("===================================================================")
    print("Project-Level Metrics Distribution")
    print("Comments\t&"+calculate_quartiles(comments))
    print("Ratings\t&" + calculate_quartiles(ratings))
    print("Average Ratings\t&" + calculate_quartiles(average_ratings))

    forks , open_issues,stargazers = get_git_projects_meta(conn)

    print("Forks\t&" + calculate_quartiles(forks))
    print("Open Issues\t&" + calculate_quartiles(open_issues))
    print("Stargazers\t&"+ calculate_quartiles(stargazers))
    print("===================================================================")


if __name__ == '__main__':
    main()
