function st = BuildStruct(var)

st = struct.empty();

for i = 1 : numel(var)
    
    levels = split(var(i),'|');
    st = addlevel(st, levels, i);
    
end

end

function st = addlevel(st, levels, id)

if ~isempty(levels)
    
    name = levels(1);
    if ~isvarname(name)
        name = genvarname(levels(1));
    end
    
    if isfield(st, name)
        st.(name).Value = addlevel(st.(name).Value, levels(2:end), id);
    else
        if length(levels) == 1
            myId = id;
        else
            myId = 0;
        end
        myS = struct('Name', levels(1),'Id', myId, 'Value', struct.empty() );
        myS.Value = addlevel(myS.Value, levels(2:end), id);
        
        if isempty(st)
            st = struct(name, myS);
        else
            st.(name) = myS;
        end
        
    end
    
end

end