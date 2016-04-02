module keyvalues.stack;

struct Stack(Type)
{
    Type[] data;
    size_t index;

    @disable this();

    this(size_t initialSize = 1)
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
