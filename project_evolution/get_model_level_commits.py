from pydriller import RepositoryMining
import logging
import sys

logging.basicConfig(filename='commits.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)

logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))
def get_model_level_commits(file_path, repo,hash,model_verbatim,model_file,id):
    no_of_commits = 0
    authors_set = set()
    commits_date = []
    for commits in RepositoryMining(repo, filepath=file_path,to_commit=hash).traverse_commits():
        model_verbatim.insert(id, model_file, commits)
        no_of_commits += 1
        authors_set.add(commits.author.email)
        commits_date.append(commits.author_date.astimezone())
    commits_date.sort()
    start_date = commits_date[0]
    end_date  = commits_date[len(commits_date)-1]
    life_time =end_date - start_date
    mdl_lt = life_time.days + life_time.seconds / 86400
    logging.info("Start_date of {} : {}".format(file_path,start_date))
    logging.info("end_date of {} : {}".format(file_path, end_date))
    logging.info("life_time of {} : {}".format(file_path, mdl_lt))
    logging.info("Number of authors of {} : {}".format(file_path, len(authors_set)))
    logging.info("no_of_commits of {} : {}".format(file_path, no_of_commits))

    return no_of_commits, len(authors_set),start_date, end_date, mdl_lt

#get_model_level_commits("demos/stellaris_pil_mdlref_mr.mdl","https://github.com/kyak/stellaris_ert")
#get_model_level_commits("clgen/models/tensorflow_backend.py","https://github.com/50417/DeepFuzzSL")
