import logging
from datetime import datetime
import matplotlib
import matplotlib.pyplot as plt
"""matplotlib.use("pgf")"""
matplotlib.rcParams.update({
    'font.family': 'Times New Roman',
    'font.size' : 14,

})
from analyzeProjects import create_connection
logging.basicConfig(filename='analyze_projects.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)

#logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
def date_range(start, end, intv):

    diff = (end  - start ) / intv
    ans = []
    for i in range(intv):
        endpoint = (start + diff * i)
        date_string = endpoint.strftime('%Y-%m-%d %H:%M:%S')
        ans.append(date_string)
    return ans

def get_project_ids(conn):
    cur = conn.cursor()
    project_ids_sql = "select id from github_projects_commit_info"
    cur.execute(project_ids_sql)
    rows = cur.fetchall()
    project_ids = [r[0] for r in rows]
    return project_ids
def get_start_end_dates(conn,id):
    sql = "select first_commit,last_commit from GitHub_Projects_Commit_Info where id ="+str(id)
    cur = conn.cursor()

    cur.execute(sql)
    rows = cur.fetchall()


    for r in rows:
        #x = time.strptime(r[0], '%Y-%m-%d %H:%M:%S')
        start_date = r[0].split(" ")
        start_date[-1] = start_date[-1][:-7]
        start_date = " ".join(start_date)

        start_date = datetime.strptime(start_date, '%Y-%m-%d %H:%M:%S')

        end_date = r[1].split(" ")
        end_date[-1] = end_date[-1][:-7]
        end_date = " ".join(end_date)

        end_date = datetime.strptime(end_date, '%Y-%m-%d %H:%M:%S')
        logging.info("Start Date : "+start_date.strftime('%Y-%m-%d %H:%M:%S'))
        logging.info("End Date : "+end_date.strftime('%Y-%m-%d %H:%M:%S'))
    return start_date,end_date

def project_total_commits(conn,id):
    cur = conn.cursor()
    sql = "select total_number_of_commits from Github_Projects_commit_info where id  ="+str(id)
    cur.execute(sql)

    rows = cur.fetchall()
    count = int(rows[0][0])
    return count

def model_total_commits(conn,id):
    cur = conn.cursor()
    sql = "select count(distinct hash) from model_commits where id  ="+str(id)
    cur.execute(sql)

    rows = cur.fetchall()
    count = int(rows[0][0])
    return count

def model_modified_total_commits(conn,id):
    cur = conn.cursor()
    sql = "select count(*) from model_commits where id  ="+str(id)
    cur.execute(sql)

    rows = cur.fetchall()
    count = int(rows[0][0])
    return count

def get_number_of_model_under_development(conn,id):
    cur = conn.cursor()
    sql = "select count(distinct(model_name)) c from Model_commits where id  ="+str(id)
    cur.execute(sql)

    rows = cur.fetchall()
    count = int(rows[0][0])
    return count



def get_project_commit_distribution(conn,id,date_range_buckets):
    cur = conn.cursor()
    total_commits = project_total_commits(conn,id)
    rel_commits_distribution = []
    commit_counts = []
    logging.info(date_range_buckets)
    for i in range(len(date_range_buckets)-1):
        sql = "select count(*) as c from Project_commits where id ="+ \
              str(id) +" and committer_date>="+"'"+date_range_buckets[i]+"' and "+\
                                                           "committer_date<" +"'"+date_range_buckets[i+1]+"'"
        logging.info("Project Commits Distribute SQL : "+ sql)
        cur.execute(sql)
        rows = cur.fetchall()
        count = int(rows[0][0])
        commit_counts.append(count)
        rel_commits_distribution.append((count/total_commits)*100)
    sql = "select count(*) as c from Project_commits where id =" + \
          str(id) + " and committer_date>=" + "'" + date_range_buckets[len(date_range_buckets)-1]+"'"
    logging.info("Project Commits Distribute SQL : "+ sql)
    cur.execute(sql)
    rows = cur.fetchall()
    count = int(rows[0][0])
    commit_counts.append(count)
    rel_commits_distribution.append(count / total_commits*100)
    logging.info("Project ID {} LifeCycle: {}".format(id,rel_commits_distribution) )
    assert(total_commits == sum(commit_counts))
    return rel_commits_distribution


def get_model_commit_distribution(conn,id,date_range_buckets):
    cur = conn.cursor()
    total_commits = model_total_commits(conn,id)
    rel_commits_distribution = []
    commit_counts = []
    logging.info(date_range_buckets)
    for i in range(len(date_range_buckets)-1):
        sql = "select count(distinct hash) as c from Model_commits where id ="+ \
              str(id) +" and committer_date>="+"'"+date_range_buckets[i]+"' and "+\
                                                           "committer_date<" +"'"+date_range_buckets[i+1]+"'"
        logging.info("Model Commits Distribute SQL : "+ sql)
        cur.execute(sql)
        rows = cur.fetchall()
        count = int(rows[0][0])
        commit_counts.append(count)
        rel_commits_distribution.append((count/total_commits)*100)
    sql = "select count(distinct hash) as c from Model_commits where id =" + \
          str(id) + " and committer_date>=" + "'" + date_range_buckets[len(date_range_buckets)-1]+"'"
    logging.info("Model Commits Distribute SQL : "+ sql)
    cur.execute(sql)
    rows = cur.fetchall()
    count = int(rows[0][0])
    commit_counts.append(count)
    rel_commits_distribution.append(count / total_commits*100)
    logging.info("Project ID {} Model Commits: {}".format(id,rel_commits_distribution) )
    #assert(total_commits == sum(commit_counts))
    return rel_commits_distribution

def get_model_modified_commit_distribution(conn,id,date_range_buckets):
    cur = conn.cursor()
    total_commits = model_modified_total_commits(conn,id)
    rel_commits_distribution = []
    commit_counts = []
    logging.info(date_range_buckets)
    for i in range(len(date_range_buckets)-1):
        sql = "select count(*) as c from Model_commits where id ="+ \
              str(id) +" and committer_date>="+"'"+date_range_buckets[i]+"' and "+\
                                                           "committer_date<" +"'"+date_range_buckets[i+1]+"'"
        logging.info("Model Commits Distribute SQL : "+ sql)
        cur.execute(sql)
        rows = cur.fetchall()
        count = int(rows[0][0])
        commit_counts.append(count)
        if total_commits==0:
            rel_commits_distribution.append(0)
        else:
            rel_commits_distribution.append((count / total_commits) * 100)
    sql = "select count(*) as c from Model_commits where id =" + \
          str(id) + "  and committer_date>=" + "'" + date_range_buckets[len(date_range_buckets)-1]+"'"
    logging.info("Model Commits Distribute SQL : "+ sql)
    cur.execute(sql)
    rows = cur.fetchall()
    count = int(rows[0][0])
    commit_counts.append(count)
    if total_commits == 0:
        rel_commits_distribution.append(0)
    else:
        rel_commits_distribution.append((count / total_commits) * 100)
    logging.info("Project ID {} Model Modified: {}".format(id,rel_commits_distribution) )
    #assert(total_commits == sum(commit_counts))
    return rel_commits_distribution

def get_model_development_distribution(conn,id,date_range_buckets):
    cur = conn.cursor()
    total_models = get_number_of_model_under_development(conn,id)
    model_dev_ratio_distribution = []
    logging.info(date_range_buckets)
    for i in range(len(date_range_buckets)-1):
        sql = "select count(distinct(model_name)) c from Model_commits where id ="+ \
              str(id) +"  and committer_date>="+"'"+date_range_buckets[i]+"' and "+\
                                                           "committer_date<" +"'"+date_range_buckets[i+1]+"'"
        logging.info("Model Commits Distribute SQL : "+ sql)
        cur.execute(sql)
        rows = cur.fetchall()
        count = int(rows[0][0])
        model_dev_ratio_distribution.append((count/total_models)*100)
    sql = "select count(distinct(model_name)) c from Model_commits where id =" + \
          str(id) + "  and committer_date>=" + "'" + date_range_buckets[len(date_range_buckets)-1]+"'"
    logging.info("Model Commits Distribute SQL : "+ sql)
    cur.execute(sql)
    rows = cur.fetchall()
    count = int(rows[0][0])
    model_dev_ratio_distribution.append(count / total_models*100)
    logging.info("Project ID {} Model Ratio: {}".format(id,model_dev_ratio_distribution) )
    #assert(total_commits == sum(commit_counts))
    return model_dev_ratio_distribution

def get_average_by_col(a):
    return list(map(lambda x:sum(x)/len(x),zip(*a)))


def plot(data_lst,xlabel="Project life time", ylabel=None,figurename = None):
    xval = [1,2,3,4,5,6,7,8,9,10]
    xtickpos = [1,5,10]
    xticksLabel = ["0-10%","40-50%","90-100%"]
    max_y_val = round(max(data_lst))
    y_delta = 5
    if max_y_val>50:
        y_delta =10
    ytickpos = [ i for i in range(0,max_y_val,y_delta)]

    ytickslabel = ["{}%".format(i) for i in range(0,max_y_val,y_delta)]
    ax = plt.subplot()
    ax.set_xticks(xtickpos)
    ax.set_xticklabels(xticksLabel)
    ax.set_yticks(ytickpos)
    ax.set_yticklabels(ytickslabel)

    ax.bar(xval,data_lst,color ='white',edgecolor='black')
    #ax.bar(xval, data_lst, color='white', edgecolor='blue')
    #ax.bar(xval, data_lst, color='white', edgecolor='green')
    plt.grid(True,axis='y')
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.savefig(figurename)
    plt.close()
    #plt.show()


def plot_all(data_lst,xlabel="Project life time", ylabel=None,figurename = None):

    # Idea and Logic : https://stackoverflow.com/questions/14270391/python-matplotlib-multiple-bars/14270539
    xval = [1,2,3,4,5,6,7,8,9,10]
    xtickpos = [0,4,9]
    xticksLabel = ["0-10%","40-50%","90-100%"]
    max_y_val = 50#round(max(data_lst))
    y_delta = 5
    if max_y_val>50:
        y_delta =10
    ytickpos = [ i for i in range(0,max_y_val,y_delta)]

    ytickslabel = ["{}%".format(i) for i in range(0,max_y_val,y_delta)]
    patterns = [ "\\", "OO", "--", "*"]
    #Number of bars per xtick
    n_bars = len(data_lst)
    total_width  =0.8
    single_width =1
    bar_width = total_width/n_bars

    # Handles for legends
    bars =[]
    ax = plt.subplot()
    ax.set_xticks(xtickpos)
    ax.set_xticklabels(xticksLabel)
    ax.set_yticks(ytickpos)
    ax.set_yticklabels(ytickslabel)

    for i, (name,values) in enumerate(data_lst.items()):
        x_offset = (i-n_bars/2) * bar_width + bar_width/2
        for x,y in enumerate(values):
            bar = ax.bar(x + x_offset, y, width=bar_width * single_width,hatch = patterns[i],color ='white',edgecolor='black')
        bars.append(bar[0])
    #ax.bar(xval-0.1,data_lst,color ='white',edgecolor='black')
    #ax.bar(xval, data_lst, color='white', edgecolor='blue')
    #ax.bar(xval, data_lst, color='white', edgecolor='green')
    plt.grid(True,axis='y')
    plt.xlabel(xlabel)
    #plt.ylabel(ylabel)
    ax.legend(bars, data_lst.keys())
    figure = plt.gcf()

    figure.set_size_inches(8, 3)

    plt.savefig(figurename)
    plt.show()

def main():
    database = ""

    # create a database connection
    conn = create_connection(database)
    project_ids = get_project_ids(conn)

    projects_commit_dist = []
    model_commit_dist = []
    model_modified_commit_dist = []
    model_development_dist = []

    for id in project_ids:
        start_date, end_date = get_start_end_dates(conn,id)
        date_range_buckets = date_range(start_date, end_date, intv=10)
        projects_commit_dist.append(get_project_commit_distribution(conn,id,date_range_buckets))
        model_commit_dist.append(get_model_commit_distribution(conn,id,date_range_buckets))
        model_modified_commit_dist.append(get_model_modified_commit_distribution(conn,id,date_range_buckets))
        model_development_dist.append(get_model_development_distribution(conn,id,date_range_buckets))

    avg_project_commit_dist = get_average_by_col(projects_commit_dist)

    logging.info("Average Project Distribution of all projects:{}".format(avg_project_commit_dist))
    plot(avg_project_commit_dist,ylabel="Project Commits",figurename="Project_commit_dist.pdf")

    avg_model_commit_dist = get_average_by_col(model_commit_dist)
    logging.info("Average Model Distribution of all projects:{}".format(avg_model_commit_dist))
    plot(avg_model_commit_dist,ylabel="Model Commits",figurename="Model_commit_dist.pdf")

    avg_model_modified_commit_dist = get_average_by_col(model_modified_commit_dist)
    logging.info("Average Model Modified Distribution of all projects:{}".format(avg_model_modified_commit_dist))
    plot(avg_model_modified_commit_dist, ylabel = "Committed Model Modifications",figurename="modified_model_commit_dist.pdf")

    avg_model_development_dist = get_average_by_col(model_development_dist)

    logging.info("Average Model Development Ratio Distribution of all projects:{}".format(avg_model_development_dist))
    plot(avg_model_development_dist, ylabel="Models under development", figurename="model_under_development.pdf")

    project_lifecycles = {
        "Project Commits":avg_project_commit_dist,
        "Model Commits":avg_model_commit_dist,
        "Committed Model Modifications":avg_model_modified_commit_dist,
        "Models under development":avg_model_development_dist
    }

    plot_all(project_lifecycles,xlabel="Project life time", ylabel=None,figurename = "all_project_evolution.pdf")
    #print(projects_commit_dist)
        #get_model_commit_distribution(conn,id)
        #get_model_commit_distribution(conn,id)



if __name__ == '__main__':
    #print(get_average_by_col([[10,2,3,4],[1,2,3,4],[1,2,3,4]]))
    main()
