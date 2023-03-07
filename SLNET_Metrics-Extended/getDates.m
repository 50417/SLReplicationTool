function dates=getDates(modelName)
OrigCreationDate = get_param(modelName, 'Created');
LastChangeDate = get_param(modelName, 'LastModifiedDate');
dates = {OrigCreationDate, LastChangeDate};