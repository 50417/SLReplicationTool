from sqlalchemy import create_engine, Column, Integer, String, DateTime, Boolean,Float,Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship, load_only
from sqlalchemy.schema import PrimaryKeyConstraint
from datetime import datetime
Base = declarative_base()


class Model_commits_verbatim(Base):
	'''
	model class for Simulink Repo Info
	'''
	__tablename__ = "Model_commits"
	id = Column('id', Integer)
	model_name = Column('model_name', String)
	hash = Column('hash',String)
	msg = Column('msg',String)
	author_name = Column('author_name',String)
	author_email = Column('author_email', String)
	committer_name = Column('committer_name', String)
	committer_email = Column('committer_email', String)
	author_date = Column("author_date",DateTime)
	author_timezone = Column('author_timezone',Integer)
	committer_date = Column('committer_date',DateTime)
	committer_timezone = Column('committer_timezone',Integer)
	branches = Column('branches',Text)
	in_main_branch = Column('in_main_branch',Boolean)
	merge = Column('merge', Boolean)
	modified = Column('modifications',Boolean)
	parents = Column('parents',Text)
	project_name = Column('project_name',String)
	project_path = Column('project_path', String)
	deletions = Column('deletions',Integer)
	insertions = Column('insertions', Integer)
	lines = Column("lines", Integer)
	files = Column("files", Integer)
	dmm_unit_size = Column("dmm_unit_size",Float)
	dmm_unit_complexity = Column("dmm_unit_complexity", Float)
	dmm_unit_interfacing = Column("dmm_unit_interfacing", Float)
	__table_args__ = (
		PrimaryKeyConstraint(
			id,
			model_name,
			hash),
		{})


	def __init__(self, id,model_name,commit_obj):
		self.id = id
		self.model_name = model_name
		self.hash = commit_obj.hash
		self.msg = commit_obj.msg
		self.author_name = commit_obj.author.name
		self.author_email = commit_obj.author.email
		self.committer_name = commit_obj.committer.name
		self.committer_email = commit_obj.committer.email
		self.author_date = commit_obj.author_date.astimezone()
		self.author_timezone = commit_obj.author_timezone
		self.committer_date = commit_obj.committer_date.astimezone()
		self.committer_timezone = commit_obj.committer_timezone
		self.branches = str(commit_obj.branches)
		self.in_main_branch = commit_obj.in_main_branch
		self.merge = commit_obj.merge
		modified = False
		for obj in commit_obj.modifications:
			if obj.old_path is not None and obj.new_path is not None and model_name.endswith(obj.new_path):
				modified = True

		self.modified = modified
		#self.modifications = commit_obj.modifications
		self.parents = str(commit_obj.parents)
		self.project_name = commit_obj.project_name
		self.project_path = commit_obj.project_path
		self.deletions = commit_obj.deletions
		self.insertions = commit_obj.insertions
		self.lines = commit_obj.lines
		self.files = commit_obj.files
		self.dmm_unit_size = commit_obj.dmm_unit_size
		self.dmm_unit_complexity = commit_obj.dmm_unit_complexity
		self.dmm_unit_interfacing = commit_obj.dmm_unit_interfacing





class Model_commits_verbatim_Controller(object):
	def __init__(self,db_name):
		# In memory SQlite database . URI : sqlite:///:memory:
		# URL = driver:///filename or memory
		self.engine = create_engine('sqlite:///'+db_name, echo=True) # Hard coded Database Name . TODO : Make it user configurable/
		#Create Tables
		Base.metadata.create_all(bind=self.engine)
		self.Session = sessionmaker(bind=self.engine)

	def insert(self, id, model_name, commit_obj):
		session = self.Session()
		tmp_obj = Model_commits_verbatim( id, model_name,commit_obj)
		session.add(tmp_obj)
		session.commit()
		session.close()