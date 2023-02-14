from pydriller import RepositoryMining
import logging
import sys

logging.basicConfig(filename='commits.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)

#logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
def get_project_level_commits(repo_url,hash,project_verbatim,id):
    hashes_per_project = []
    commits_dates_per_project = []
    merge_commits_per_project = set()
    authors_per_project = set()
    commit_per_day = {}
    model_commits = []
    model_authors = set()
    for commit in RepositoryMining(repo_url,to_commit=hash).traverse_commits():
        project_verbatim.insert(id,commit)
        hashes_per_project.append(commit.hash)
        authors_per_project.add(commit.author.email)
        commits_dates_per_project.append(commit.author_date.astimezone())
        date_without_time = commit.author_date.astimezone().date()
        if date_without_time in commit_per_day:
            commit_per_day[date_without_time] = commit_per_day[date_without_time]+1
        else:
            commit_per_day[date_without_time] = 1
        if commit.merge:
            merge_commits_per_project.add(commit.hash)
        #logging.info('Hash {}, author {} , date {}'.format(commit.hash, commit.author.name, commit.author_date))
    commits_dates_per_project.sort()
    start_date = commits_dates_per_project[0]
    end_date = commits_dates_per_project[len(commits_dates_per_project)-1]

    project_lifetime =end_date-start_date
    #logging.info(type(end_date))


    logging.info("Number of Commits :{} ".format(len(hashes_per_project)))
    logging.info("Number of Merge Commits  :{} ".format(len(merge_commits_per_project)))
    logging.info("Number of Authors :{}".format(len(authors_per_project)))
    commit_per_day_sum = 0
    for k,no_of_commit in commit_per_day.items():
        #logging.info(v)
        commit_per_day_sum += no_of_commit
    #logging.info(commit_per_day_sum/(float(project_lifetime.days)))

    #model
    for commit in RepositoryMining(repo_url,only_modifications_with_file_types=['.slx','.mdl']).traverse_commits():
        model_commits.append(commit.hash)
        model_authors.add( commit.author.email)
    logging.info("Number of Model Commits :{}".format(len(model_commits)))
    logging.info("Number of Model Authors :{}".format(len(model_authors)))
    cpds = commit_per_day_sum
    proj_lt = project_lifetime.days + project_lifetime.seconds / 86400
    logging.info("Lifetime :{} days".format(proj_lt))
    if project_lifetime.days>0:
        cpds = commit_per_day_sum / (float(proj_lt))
    return len(hashes_per_project), len(merge_commits_per_project), len(authors_per_project) ,\
				 commits_dates_per_project[0], commits_dates_per_project[len(commits_dates_per_project)-1], \
           (proj_lt),cpds ,\
				 len(model_commits), len(model_authors)

#get_project_level_commits("https://github.com/alesgraz/kinect2-SDK-for-Simulink ")
