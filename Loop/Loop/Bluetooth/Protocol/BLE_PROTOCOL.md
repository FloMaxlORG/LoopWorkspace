
# FlyingDiabetic Bluetooth Protocol

Version: 1.0

---

## Purpose

This protocol provides live diabetes data from the Loop iOS application to
external Bluetooth Low Energy devices.

The protocol is designed to be:

- compact
- fast
- versioned
- extensible
- backwards compatible

Only little-endian encoding is used.

---

# GATT Layout

Service UUID

6D6F6F70-0001-4C4F-4F50-424C454C4F50

Characteristic UUID

6D6F6F70-0002-4C4F-4F50-424C454C4F50

Properties

- Read
- Notify

---

# Packet Structure

Packet Type 1
Live Data Packet

Length

17 Bytes

| Byte | Size | Type | Description |
|------|------|------|-------------|
|0|1|UInt8|Protocol Version|
|1|1|UInt8|Packet Type|
|2|1|UInt8|Flags|
|3-4|2|UInt16|Current Glucose (mg/dL)|
|5|1|UInt8|Trend|
|6|1|Int8|Delta (mg/dL)|
|7-8|2|Int16|IOB ×100|
|9-10|2|UInt16|COB (g)|
|11-12|2|UInt16|Predicted Glucose|
|13-16|4|UInt32|Unix Timestamp|

---

# Packet Types

| Value | Meaning |
|-------|---------|
|1|Live Data|
|2|Pump Status|
|3|Sensor Status|
|4|Device Status|
|5|Heartbeat|

Currently only packet type 1 is implemented.

---

# Flags

Byte 2

Bit definitions

Bit 0

Closed Loop Enabled

0 = Open Loop

1 = Closed Loop

Bit 1

CGM Connected

Bit 2

Pump Connected

Bit 3

Temporary Target Active

Bit 4

Bolus In Progress

Bits 5-7

Reserved

Reserved bits shall always be zero.

---

# Trend Values

| Value | Meaning |
|-------|---------|
|0|Unknown|
|1|Double Down|
|2|Single Down|
|3|Forty Five Down|
|4|Flat|
|5|Forty Five Up|
|6|Single Up|
|7|Double Up|

---

# Delta

Byte 6 is a signed Int8 representing the change from the

immediately preceding accepted glucose sample.

-127 ... +127 = change in mg/dL

-128 = delta unavailable

---

# IOB

Stored as

IOB ×100

Examples

145

=

1.45 U

50

=

0.50 U

---

# Timestamp

Unix timestamp

Seconds since

1970-01-01 UTC

---

# Notifications

Whenever Loop data changes, the complete packet is transmitted.

Partial packets are never sent.

All fields always belong to the same Loop state.

---

# Versioning

Byte 0 contains the protocol version.

Breaking changes require a version increment.

Future versions shall preserve backwards compatibility whenever possible.

---

# Future Extensions

Packet Type 2

Pump Status

- Reservoir
- Battery
- Delivery Status

Packet Type 3

Sensor Status

- Sensor Age
- Warmup
- Expiration

Packet Type 4

Device Status

- Phone Battery
- Bluetooth State

Packet Type 5

Heartbeat

Used to verify connection health.

## Design Principles

1. One notification = one complete system state.

2. All fields describe the same Loop calculation.

3. Receivers never need to combine multiple packets.

4. Packets are append-only whenever possible.

5. Unknown packet types must be ignored.

6. Unknown flag bits must be ignored.

7. All integers are little-endian.

8. BLE notifications are preferred over polling.
