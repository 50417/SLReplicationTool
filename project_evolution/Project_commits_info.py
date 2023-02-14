from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship, load_only
from datetime import datetime
Base = declarative_base()


class Project_commits_info(Base):
	'''
	model class for Simulink Repo Info
	'''
	__tablename__ = "GitHub_Projects_Commit_Info"
	id = Column('id', Integer, primary_key=True)
	total_number_of_commits = Column('Total_number_of_commits', Integer)
	number_of_merge_commits = Column('Number_of_merge_commits', Integer)
	number_of_authors = Column('Number_of_authors', Integer)
	first_commit = Column('First_commit', DateTime)
	last_commit = Column('Last_commit', DateTime)
	lifeTime_in_days = Column('LifeTime_in_days', Float)
	commit_per_day = Column('Commit_per_day', Integer)
	model_commits = Column('Model_commits', Integer)
	model_authors = Column('Model_authors', Integer)

	def __init__(self, id, total_number_of_commits, number_of_merge_commits, number_of_authors ,
				 first_commit, last_commit, lifeTime_in_days, commit_per_day,
				 model_commits, model_authors):
		self.id = id
		self.total_number_of_commits = total_number_of_commits
		self.number_of_merge_commits = number_of_merge_commits
		self.number_of_authors =number_of_authors
		self.first_commit = first_commit
		self.last_commit = last_commit
		self.lifeTime_in_days = lifeTime_in_days
		self.commit_per_day = commit_per_day
		self.model_commits = model_commits
		self.model_authors = model_authors


class Project_commits_info_Controller(object):
	def __init__(self,db_name):
		# In memory SQlite database . URI : sqlite:///:memory:
		# URL = driver:///filename or memory
		self.engine = create_engine('sqlite:///'+db_name, echo=True) # Hard coded Database Name . TODO : Make it user configurable/
		#Create Tables
		Base.metadata.create_all(bind=self.engine)
		self.Session = sessionmaker(bind=self.engine)

	def insert(self, id, total_number_of_commits, number_of_merge_commits, number_of_authors ,
				 first_commit, last_commit, lifeTime_in_days, commit_per_day,
				 model_commits, model_authors):

		session = self.Session()
		tmp_project_commits_info = Project_commits_info( id, total_number_of_commits, number_of_merge_commits, number_of_authors ,
				 first_commit, last_commit, lifeTime_in_days, commit_per_day,
				 model_commits, model_authors)
		session.add(tmp_project_commits_info)
		session.commit()
		session.close()