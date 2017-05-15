#!/usr/bin/env bash

Greeter_sayHi() {
  local -r name="${1:-stranger}"

  echo "Hi ${name}!"
}

Greeter_isPresent() {
  echo "Yes, $USER, I am here."
}
