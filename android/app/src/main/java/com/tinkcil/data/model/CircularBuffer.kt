package com.tinkcil.data.model

class CircularBuffer<T>(private val capacity: Int) {
    private val buffer = ArrayList<T>(capacity)
    private var writeIndex = 0

    val size: Int get() = buffer.size

    @Synchronized
    fun add(element: T) {
        if (buffer.size < capacity) {
            buffer.add(element)
        } else {
            buffer[writeIndex] = element
        }
        writeIndex = (writeIndex + 1) % capacity
    }

    @Synchronized
    fun toList(): List<T> {
        if (buffer.size < capacity) return ArrayList(buffer)
        val result = ArrayList<T>(capacity)
        for (i in 0 until capacity) {
            result.add(buffer[(writeIndex + i) % capacity])
        }
        return result
    }

    @Synchronized
    fun clear() {
        buffer.clear()
        writeIndex = 0
    }
}
