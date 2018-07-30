#ifndef QUEUE_H
#define QUEUE_H

#define MAX_QUEUE_SIZE 20

msg_t queue[MAX_QUEUE_SIZE];
uint16_t size = 0;
uint16_t rear = 0;
uint16_t front = 0;

void enqueue(msg_t message) {
    queue[rear] = message;
    rear = (rear + 1) % MAX_QUEUE_SIZE;
    size++;
}

msg_t dequeue() {
    msg_t m = queue[front];
    front = (front + 1) % MAX_QUEUE_SIZE;
    size--;
    return m;
}

bool queueEmpty() {
    return size == 0;
}

msg_t peek() {
   return queue[front];
}

#endif
