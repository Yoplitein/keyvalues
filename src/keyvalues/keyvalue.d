module keyvalues.keyvalue;

import std.algorithm;
import std.array;
import std.string;
import std.traits;

struct KeyValue
{
    string key;
    bool hasSubkeys;
    
    union
    {
        string value;
        KeyValue[] subkeys;
    }
    
    KeyValue[] opIndex(string name)
    in { assert(hasSubkeys); }
    body
    {
        return subkeys
            .filter!(subkey => subkey.key == name)
            .array
        ;
    }
    
    string toString()
    {
        string valueRepr;
        
        if(hasSubkeys)
            valueRepr = subkeys
                .map!(sk => sk.toString)
                .join(",\n")
                .replace("\n", "\n    ")
                .Identity!(str => "[\n    %s\n]".format(str))
            ;
        else
            valueRepr = value
                .formatEscapes
                .Identity!(str => `"%s"`.format(str))
            ;
        
        return "KeyValue(\n    \"%s\",\n    %s\n)".format(
            key.formatEscapes,
            valueRepr.replace("\n", "\n    "),
        );
    }
}

private string formatEscapes(string str)
{
    return str
        .replace("\\", `\\`)
        .replace("\"", `\"`)
        .replace("\n", `\n`)
        .replace("\t", `\t`)
    ;
}
