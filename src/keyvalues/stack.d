module keyvalues.stack;

struct Stack(Type)
{
    Type[] data;
    size_t index;

    @disable this();

    this(size_t initialSize)
    {
        data.length = initialSize;
    }

    void push(Type datum)
    {
        if(data.length <= index)
            data.length *= 2;

        data[index++] = datum;
    }

    Type pop()
    {
        if(empty)
            throw new Exception("stack underflow");

        return data[--index];
    }

    @property ref Type top()
    {
        return data[index - 1];
    }

    @property bool empty()
    {
        return index == 0;
    }
}

unittest
{
    auto stack = Stack!int(2);
    
    assert(stack.empty);
    stack.push(1);
    assert(!stack.empty);
    assert(stack.top == 1);
    assert(stack.pop == 1);
    assert(stack.empty);
}
