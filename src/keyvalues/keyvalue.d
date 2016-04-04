module keyvalues.keyvalue;

import std.algorithm;
import std.array;
import std.string;
import std.traits;

/++
    In-memory representation of a KeyValues object.
+/
struct KeyValue
{
    string key; ///The key of this KeyValue.
    bool hasSubkeys; ///Whether this KeyValue has subkeys.
    
    union
    {
        string value; ///The value of this KeyValue, if hasSubkeys is false.
        KeyValue[] subkeys; ///The subkeys of this KeyValue, if hasSubkeys is true.
    }
    
    /++
        Returns all subkeys whose key equal name.
    +/
    KeyValue[] opIndex(string name)
    in { assert(hasSubkeys); }
    body
    {
        return subkeys
            .filter!(subkey => subkey.key == name)
            .array
        ;
    }
    
    /++
        Returns a pretty printed string representation of this KeyValue.
    +/
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
    
    //TODO: method to serialize to KeyValues text
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
