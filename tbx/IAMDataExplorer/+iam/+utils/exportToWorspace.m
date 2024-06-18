function exportToWorspace(data)

if isdeployed()
    uisave('data')
else
    var = inputdlg('Please select a name','Export to Workspace',1);
    assignin('base', var{1}, data)
end

end