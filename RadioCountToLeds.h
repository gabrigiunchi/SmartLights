#ifndef RADIO_COUNT_TO_LEDS_H
#define RADIO_COUNT_TO_LEDS_H

typedef nx_struct radio_count_msg {
  nx_uint16_t destination;
  nx_uint16_t commandCode;
} msg_t;

enum {
  AM_RADIO_COUNT_MSG = 6,
};

#endif
