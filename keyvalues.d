module keyvalues;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.string;
import std.traits;
import std.uni;

import stack;

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

struct Optional {}

KeyValue parseKeyValues(string text)
{
    return text.lex.parse;
}

Layout deserializeKeyValues(Layout)(KeyValue root, string path = "root")
{
    static assert(deserializable!Layout, "Cannot deserialize to " ~ Layout.stringof);
    
    Layout result;
    
    foreach(fieldName; __traits(allMembers, Layout))
    {
        enum getMember = "__traits(getMember, Layout, fieldName)";
        alias FieldType = typeof(mixin(getMember));
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
    
    return result;
}

private:

enum decodable(Layout) = isScalarType!Layout || isSomeString!Layout;
enum deserializable(Layout) = is(Layout == struct) && __traits(isPOD, Layout);

enum TokenType
{
    str,
    objectStart,
    objectEnd
}

struct Position
{
    uint line = 1;
    uint column = 1;
    
    string toString()
    {
        return "line %d col %d".format(line, column);
    }
}

struct Token
{
    TokenType type;
    string value;
    Position position;
}

struct PositionTracker
{
    private string data;
    private Position _position;
    
    alias data this; //forward all other range primitives
    
    void popFront()
    {
        data.popFront;
        
        _position.column++;
        
        if(data.empty)
            return;
        
        if(data.front == '\n')
        {
            _position.line++;
            _position.column = 1;
        }
    }
    
    @property Position position()
    {
        return _position;
    }
}

string formatEscapes(string str)
{
    return str
        .replace("\\", `\\`)
        .replace("\"", `\"`)
        .replace("\n", `\n`)
        .replace("\t", `\t`)
    ;
}

void error(Args)(string fmt, Args args)
{
    throw new Exception(fmt.format(args));
}

Token[] lex(string text)
{
    Appender!(Token[]) result;
    auto keyvaluesText = PositionTracker(text);
    
    void put(TokenType type, lazy string value = null)
    {
        auto pos = keyvaluesText.position;
        
        result.put(Token(type, value, pos));
    }
    
    while(!keyvaluesText.empty)
    {
        switch(keyvaluesText.front)
        {
            case '"':
                put(TokenType.str, keyvaluesText.lexQuotedString);
                
                break;
            case '{':
                put(TokenType.objectStart);
                keyvaluesText.popFront;
                
                break;
            case '}':
                put(TokenType.objectEnd);
                keyvaluesText.popFront;
                
                break;
            default:
                if(keyvaluesText.front.isWhite)
                {
                    while(!keyvaluesText.empty && keyvaluesText.front.isWhite)
                        keyvaluesText.popFront;
                    
                    break;
                }
                
                put(TokenType.str, keyvaluesText.lexBareString);
        }
    }
    
    return result.data;
}

string lexBareString(ref PositionTracker keyvaluesText)
{
    Appender!string result;
    
    loop:
    while(!keyvaluesText.empty)
    {
        switch(keyvaluesText.front)
        {
            case '"':
                error("Unexpected start of string at %s", keyvaluesText.position);
                
                break;
            case '{':
            case '}':
                break loop;
            default:
                if(keyvaluesText.front.isWhite)
                    break loop;
                
                result.put(keyvaluesText.front);
                keyvaluesText.popFront;
        }
    }
    
    return result.data;
}

string lexQuotedString(ref PositionTracker keyvaluesText)
{
    Appender!string result;
    auto stringPosition = keyvaluesText.position;
    
    keyvaluesText.popFront; //opening quote
    
    loop:
    while(!keyvaluesText.empty)
    {
        switch(keyvaluesText.front)
        {
            case '"':
                break loop;
            case '\\':
                keyvaluesText.popFront;
                
                if(keyvaluesText.empty)
                    error("Unterminated escape sequence at %s", keyvaluesText.position);
                
                switch(keyvaluesText.front)
                {
                    case 'n':
                        result.put("\n");
                        
                        break;
                    case 't':
                        result.put("\t");
                        
                        break;
                    default:
                        result.put(keyvaluesText.front);
                }
                
                keyvaluesText.popFront;
                
                break;
            default:
                result.put(keyvaluesText.front);
                keyvaluesText.popFront;
        }
    }
    
    if(keyvaluesText.empty)
        error("Quoted string at %s has no closing quote", stringPosition);
    
    keyvaluesText.popFront; //closing quote
    
    return result.data;
}

KeyValue parse(Token[] tokens)
{
    auto objects = Stack!KeyValue(2);
    
    objects.push(KeyValue("root", true));
    
    while(!tokens.empty)
        final switch(tokens.front.type) with(TokenType)
        {
            case str:
                auto keyPosition = tokens.front.position;
                auto nextValue = KeyValue(tokens.front.value);
                
                tokens.popFront;
                
                if(tokens.empty)
                    error("Key at %s does not have an associated value", keyPosition);
                
                final switch(tokens.front.type)
                {
                    case str:
                        nextValue.value = tokens.front.value;
                        objects.top.subkeys ~= nextValue;
                        
                        tokens.popFront;
                        
                        break;
                    case objectStart:
                        nextValue.hasSubkeys = true;
                        
                        objects.push(nextValue);
                        tokens.popFront;
                        
                        break;
                    case objectEnd:
                        error("Unexpected object close at %s", tokens.front.position);
                }
                
                break;
            case objectStart:
                error("Unexpected object open at %s", tokens.front.position);
                
                break;
            case objectEnd:
                auto obj = objects.pop;
                
                if(objects.empty)
                    error("Unmatched object close at %s", tokens.front.position);
                
                objects.top.subkeys ~= obj;
                
                tokens.popFront;
        }
    
    return objects.pop;
}
