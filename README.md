# Aluminum
**Aluminum** is a Metal encoding utility that greatly simplifies workflow.
It promotes usage of string paths and names to ease development,
hides indexing logic and provides descriptive errors.


## Features
- [x] String paths.
- [x] Eliminate attribute usage.
- [x] Descriptive assertions.
- [x] Simple API with Swift's overload abilities.
- [x] Encode values or structs without needing a bridging header.
- [x] Reusable encoder groups that are encoded once (no overhead on reuse).

## Code example 1

In order to bind a metal argument such as:
```metal
struct ArgumentBufferWithSamplerArray {
    metal::array<sampler, 10> s;
    texture2d<int, access::sample> tex;
};

kernel void my_function(device ArgumentBufferWithSamplerArray * argument_buffer)
{
  ...
}
```

All it needs is the following snippet:
```swift
let encoder = controller.makeEncoder(for: "argument_buffer", with: computeCommandEncoder)
encoder.setArgumentBuffer(buffer)

encoder.encode(samplerArray, to: "s") // visual form 
encoder.encode(texture, to: [.argument("tex")]) // path form
```

## Code example 2
Its possible to cache bindings of a function to a group and apply it on a command encoder as many times as needed.

For example, a metal function with 2 arguments:
```metal
kernel void test_argument_pointer(device uint * argument_1, device uint * argument_2)
{
    ...
}
```

Has the following snippet:
```swift
let group = controller.makeEncoderGroup()

let arg1Encoder = group.makeEncoder(for: "argument_1")
arg1Encoder.encode(buffer1)

let arg2Encoder = group.makeEncoder(for: "argument_2")
arg2Encoder.encode(buffer2)

computeCommandEncoder.apply(group)
```

## Installation
### Swift Package Manager
To integrate using Apple's Swift package manager, add the following as a dependency to your `Package.swift`:
```swift
.package(url: "https://github.com/MaximV88/Aluminum.git", .upToNextMajor(from: "1.0.0"))
```

## Documentations
Checkout the [WIKI PAGES (Usage Guide)](https://github.com/MaximV88/Aluminum/wiki) for documentations.

For more up-to-date ones, please see the header-doc. (use **alt+click** in Xcode)

<img src="https://github.com/MaximV88/Aluminum/blob/master/Resources/Documentation_bubble.png" width="600">
