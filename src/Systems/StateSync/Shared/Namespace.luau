local Namespace = {}


-- for all keys in the table, add the name to the beginning of the key
function Namespace.toNamespace(table: { [string]: any }, name: string)
    local namespace = {}
    for key, value in table do
        namespace[`${name}-{key}`] = value
    end
    return namespace
end

-- for all keys in the namespace, remove the name from the beginning of the key
function Namespace.fromNamespace(namespace: { [string]: any }, name: string)
    local orig = {}
    for key, value in namespace do
        orig[key:sub(name:len() + 1)] = value
    end
    return orig
end

return Namespace