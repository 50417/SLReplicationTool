import sqlite3
from sqlite3 import Error
import pathlib
import logging
import sys
import os, shutil
import time

from pydriller import GitRepository

from Model_commits_info import Model_commits_info_Controller
from Project_commits_info import Project_commits_info_Controller
from Project_commits_verbatim import Project_commits_verbatim_Controller
from Model_commits_verbatim import Model_commits_verbatim_Controller

logging.basicConfig(filename='commits.log', filemode='a',
					format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
					level=logging.INFO)

#logging.getLogger().addHandler(logging.StreamHandler(sys.stdout))

from get_model_level_commits import get_model_level_commits
from get_project_level_commits import get_project_level_commits
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

def get_repo_id_urls(conn):
    """
    Query tasks
    :param conn: the Connection object
    :param
    :return:
    """
    cur = conn.cursor()
    cur.execute("SELECT id,project_url,model_files,version_sha FROM GitHub_Projects ")

    rows = cur.fetchall()
    return rows
def get_id_name(conn):
    cur = conn.cursor()

    cur.execute("SELECT id FROM GitHub_Projects_Commit_Info ")

    rows = cur.fetchall()

    cur.execute("SELECT model_name FROM GitHub_Model_Commit_Info ")
    mdl_name = cur.fetchall()

    return set([ r[0] for r in rows]),set([m[0] for m in mdl_name])

def write_project_commit_info(url,id, hash,controller,project_verbatim):
    total_number_of_commits, number_of_merge_commits, number_of_authors, \
    first_commit, last_commit, lifeTime_in_days, commit_per_day, \
    model_commits, model_authors = get_project_level_commits(url,hash,project_verbatim,id)

    controller.insert(id, total_number_of_commits, number_of_merge_commits, number_of_authors, \
                                            first_commit, last_commit, lifeTime_in_days, commit_per_day, \
                                            model_commits, model_authors)
    return lifeTime_in_days

def write_model_commit_info(model_files,url,id,hash,controller, project_lifetime,model_verbatim):
    model_files_lst = model_files.split(",")
    for model_file in model_files_lst:
        if len(model_file) != 0:
            p = pathlib.Path(model_file)
            file_path = pathlib.Path(*p.parts[1:])
            logging.info("Processing {}".format(file_path))
            no_of_commits, no_of_authors,start_date, end_date, life_time = get_model_level_commits(file_path, url,hash,model_verbatim,model_file,id)
            relative_lifetime = 0
            if project_lifetime != 0:
                relative_lifetime = life_time/project_lifetime
            controller.insert(id, model_file, no_of_commits, no_of_authors,start_date, end_date, life_time,relative_lifetime)

def main():
    start = time.time()
    source_database =""
    dst_database = ""
    path = "workdir"
    dest_project_database_controller = Project_commits_info_Controller(dst_database)
    dest_model_database_controller = Model_commits_info_Controller(dst_database)

    project_verbatim = Project_commits_verbatim_Controller(dst_database)
    model_verbatim = Model_commits_verbatim_Controller(dst_database)
    # create a database connection
    conn = create_connection(source_database)
    dst_conn = create_connection(dst_database)
    with dst_conn:
        processed_id,processed_mdl_name= get_id_name(dst_conn)
    with conn:
        id_urls = get_repo_id_urls(conn)
        for id_url in id_urls:
            id, url , model_files,hash = id_url
            if not os.path.exists(path):
                os.mkdir(path)
            if url == "https://github.com/alesgraz/kinect2-SDK-for-Simulink" \
                    or url=="https://github.com/OpenCadd/Lego_nxt_car" \
                    or url=="https://github.com/StefanMack/ProjSensSys" \
                    or url=="https://github.com/chiloanel/UWMatlab"\
                    or url == "https://github.com/alesgraz/kinect2-SDK-for-Simulink":
                continue
            try:
                if id not in processed_id:
                    clone = "git clone " + url + " " + path
                    os.system(clone)  # Cloning
                    gr = GitRepository(path)
                    gr.checkout(hash)
                    url = path
                    project_lifetime = write_project_commit_info(url,id, hash,dest_project_database_controller,project_verbatim)
                    write_model_commit_info(model_files,url,id, hash,dest_model_database_controller,project_lifetime,model_verbatim)
                else:
                    logging.info("Skipping . ALready Processed {}".format(id))
            except Exception as e:
                logging.error(e)
                continue
            finally:
                shutil.rmtree(path)
    end = time.time()
    logging.info("IT took {} seconds".format(end - start))





if __name__ == '__main__':
    main()
