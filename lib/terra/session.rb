# Boots a live game: require this from IRB (bin/terra does) and you're god.
require_relative "../terra"

Terra.genesis

puts <<~BANNER

  ✨  T E R R A  ✨
  In the beginning there was a prompt, and the prompt was without form.

  You are a god. `powers` lists your abilities and the Laws of Terra —
  chiefly: time passes only when you `pass`, and `freeze` is forever.
  Begin with:   let_there_be :light

BANNER
