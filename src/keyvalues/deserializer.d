module keyvalues.deserializer;

import std.algorithm;
import std.conv;
import std.range;
import std.string;
import std.traits;

import keyvalues.keyvalue;
import keyvalues.parser;

private enum decodable(Layout) = isScalarType!Layout || isSomeString!Layout;
private enum deserializable(Layout) = is(Layout == struct) && __traits(isPOD, Layout);

/++
    Attribute for a field of a Layout which may be missing.
+/
struct Optional {}

/++
    Deserialize a KeyValues object into the given Layout.
    
    A Layout is a struct defining the structure of the KeyValues object.
    A Layout must be a plain old struct (no fancy constructors),
    contain only basic types, similarly restricted structs,
    or arrays of the aforementioned types.
    
    Params:
        root = the object to deserialize
        path = for internal use only, used to report the path to missing keys
+/
Layout deserializeKeyValues(Layout)(KeyValue root, string path = "root")
{
    static assert(deserializable!Layout, "Cannot deserialize to " ~ Layout.stringof);
    
    Layout result;
    
    foreach(fieldName; __traits(allMembers, Layout))
    {
        enum getMember = "__traits(getMember, Layout, fieldName)";
        alias FieldType = typeof(mixin(getMember));
        
        static if(isCallable!FieldType)
            continue;
        else
        {
            string serializedName = fieldName //docs use PascalCase for keys
                .take(1)
                .map!toUpper
                .chain(fieldName.drop(1))
                .to!string
            ;
            string subpath = path ~ "." ~ fieldName;
            auto subkeys = root[serializedName];
            bool required = !hasUDA!(mixin(getMember), Optional);
            
            if(subkeys.empty)
            {
                if(required)
                    throw new Exception("Required key %s not found".format(subpath));
                
                continue;
            }
            
            static if(is(FieldType == struct))
                mixin("result." ~ fieldName) = subkeys
                    .front
                    .deserializeKeyValues!FieldType(subpath)
                ;
            else static if(decodable!FieldType)
                mixin("result." ~ fieldName) = subkeys
                    .front
                    .value
                    .to!FieldType
                ;
            else static if(isDynamicArray!FieldType)
            {
                alias FieldElementType = ElementType!FieldType;
                
                static if(is(FieldElementType == struct))
                {
                    string subkeysName = FieldElementType.stringof;
                    auto subkeysPath = subpath ~ "." ~ subkeysName;
                    
                    mixin("result." ~ fieldName) = subkeys
                        .front[subkeysName]
                        .map!(kv => kv.deserializeKeyValues!FieldElementType(subkeysPath))
                        .array
                    ;
                }
                else if(decodable!FieldElementType)
                    mixin("result." ~ fieldName) = subkeys.front
                        .map!(kv => kv.value.to!FieldElementType)
                        .array
                    ;
                else
                    static assert(false, "Can't deserialize array of " ~ FieldElementType);
            }
            else
                static assert(false, "Can't deserialize " ~ FieldType.stringof);
        }
    }
    
    return result;
}

unittest
{
    struct Test
    {
        int abc;
        string def;
    }
    
    auto parsed = q{
        Abc 32
        Def "abc def"
    }.parseKeyValues;
    
    assert(parsed.deserializeKeyValues!Test == Test(32, "abc def"));
}

unittest
{
    struct Repeated
    {
        int abc;
    }
    
    struct Test
    {
        Repeated[] repeats;
        string def;
    }
    
    auto parsed = q{
        Repeats
        {
            Repeated
            {
                Abc 1
            }
            Repeated
            {
                Abc 2
            }
        }
        Def "abc def"
    }.parseKeyValues;
    
    assert(parsed.deserializeKeyValues!Test == Test([Repeated(1), Repeated(2)], "abc def"));
}
