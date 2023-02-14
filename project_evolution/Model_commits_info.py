from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.schema import PrimaryKeyConstraint
from datetime import datetime
Base = declarative_base()


class Model_commits_info(Base):
	'''
	model class for Simulink Repo Info
	'''
	__tablename__ = "GitHub_Model_Commit_Info"
	id = Column('id', Integer)
	model_name =  Column('model_name', String)
	total_number_of_commits = Column('Total_number_of_commits', Integer)
	number_of_authors = Column('Number_of_authors', Integer)
	first_commit = Column('First_commit', DateTime)
	last_commit = Column('Last_commit', DateTime)
	abs_lifeTime_in_days = Column('Abs_lifeTime_in_days', Float)
	rel_lifeTime = Column('Relative_lifeTime', Float)

	__table_args__ = (
		 PrimaryKeyConstraint(
			 id,
			 model_name),
		 {})

	def __init__(self, id,model_name, total_number_of_commits, number_of_authors ,
				 first_commit, last_commit, abs_lifeTime_in_days, rel_lifeTime):
		self.id = id
		self.model_name = model_name
		self.total_number_of_commits = total_number_of_commits
		self.number_of_authors =number_of_authors
		self.first_commit = first_commit
		self.last_commit = last_commit
		self.abs_lifeTime_in_days = abs_lifeTime_in_days
		self.rel_lifeTime = rel_lifeTime

class Model_commits_info_Controller(object):
	def __init__(self,db_name):
		# In memory SQlite database . URI : sqlite:///:memory:
		# URL = driver:///filename or memory
		self.engine = create_engine('sqlite:///'+db_name, echo=True) # Hard coded Database Name . TODO : Make it user configurable/
		#Create Tables
		Base.metadata.create_all(bind=self.engine)
		self.Session = sessionmaker(bind=self.engine)

	def insert(self, id,model_name, total_number_of_commits, number_of_authors ,
				 first_commit, last_commit, abs_lifeTime_in_days, rel_lifeTime):

		session = self.Session()
		tmp_model_commits_info = Model_commits_info( id,model_name, total_number_of_commits, number_of_authors ,
				 first_commit, last_commit, abs_lifeTime_in_days, rel_lifeTime)
		session.add(tmp_model_commits_info)
		session.commit()
		session.close()