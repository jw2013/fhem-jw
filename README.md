# IO::Async within FHEM

## Summary

Making IO::Async usable in FHEM can be as simple as:

```
use IO::Async::Loop::FHEM;

my $loop = IO::Async::Loop->new();

```

## Why shall I..?

Because the earth circled around the sun a couple of times, and while asynchronous (event driven) programming became state-of-the-art, programming languages improved support for that:

```
use Future::AsyncAwait;

# this call is non-blocking, but continues in the main loop

my $response = await $ua->do_request(
   uri => URI->new( $some_url )
);
   
# after the response becomes ready, continues here
   
print $response->as_string();

```


This only works in the context of a supported core like IO::Async::Loop.

Also, there are now many Perl modules available that provide functionality on top of IO::Async.



## Main Loop

There are three possible levels to implement an IO::Async Loop within FHEM:

### 1. IO::Async Loop based on FHEM API

It is possible to implement a working IO::Async loop using the FHEM internalTimer and selectlist functionality.

Pros:
 - not intrusive
 - can be loaded at any time
 - EXCEPT_FD works (for RPi GPIO events)

Cons:
 - performance limited by FHEM main loop
 - many indirect calls to map APIs
 - no support for MONOTONIC time
 
Example: IO::Async::Loop::FHEM

### 2. Hybrid FHEM+IO::Async Loop

Alternatively, a new main loop could be implemented similar to IO::Async::Loop::Select (or IO::Async::Loop::Poll), but in addition to IO::Async watchers for file descriptors and timers, it would also handle the FHEM selectlist and internalTimers.

This new loop would need to run INSTEAD of the FHEM main loop, so it would need to get started before entering the original main loop, e.g. by replacing the sub "execFhemTestFile".

Pros:
 - less indirect calls, better performance for IO::Async time and file watchers
 - support for MONOTONIC time possible
 - EXCEPT_FD works (for RPi GPIO events)
 
Cons:
- can only be started at initialization, before entering the main loop
- a bit more intrusive, as it replaces the main loop


### 3. FHEM running on top of IO::Async

Using the Perl tie function, it is possible to monitor the FHEM selectlist and related def hashes, and cover file descriptor related updates using IO::Async io watchers. FHEM internalTimer code can be replaced, to utilize IO::Async time watchers. Idle watchers can cover the FHEM prioQueue and readyfnlist.

Pros:
 - works with all IO::Async loops, offers best performance overall
 - both IO::Async and FHEM profit from optimized loops
 - support for MONOTONIC time possible
 
Cons:
- can only be started at initialization, before entering the main loop
- intrusive change, replaces the main loop, ties a couple of core vars
- no support for EXCEPT_FD (for RPi GPIO events)


## What is this MONOTONIC time btw?

There are two different clocks in POSIX, the realtime clock, and the monotonic clock.

While the realtime clock is supposed to always return a value equal to the network time, and might sometimes change abruptly, the monotonic clock ignores any time adjustments.

Timers, that shall fire 'at' a specific time (e.g. cronjobs), shall use the realtime clock.
Timers, that shall fire 'after' a specific time (e.g. timeouts), shall use the monotonic clock.

