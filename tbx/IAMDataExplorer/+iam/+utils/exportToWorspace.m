function exported = exportToWorspace(data)
%exportToWorspace - Export data using a workspace or file dialog
%   exportToWorspace(DATA) prompts for a workspace variable name.
%
%   EXPORTED = exportToWorspace(DATA) returns false when the workspace
%   naming dialog is cancelled. Deployed applications use a Save dialog.

exported = false;
if isdeployed()
    uisave("data")
    exported = true;
else
    variableName = inputdlg("Please select a name","Export to Workspace", ...
        [1 60],{""},struct("Resize","on"));
    if isempty(variableName)
        return
    end
    assignin("base",variableName{1},data)
    exported = true;
end

end
