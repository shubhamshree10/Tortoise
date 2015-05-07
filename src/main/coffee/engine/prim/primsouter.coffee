# (C) Uri Wilensky. https://github.com/NetLogo/Tortoise

NLType = require('../core/typechecker')

PrimsMiddle = require('./primsmiddle')
SimplePrims = require('./simpleprims')




# Theoretically, this should be packed up and moved into `SimplePrims`, but doing so would be very messy,
# and I don't want to deal with that right now.  I also fear a ginormous performance hit. --JAB (4/30/15)
equality = (a, b) ->
  typeA = NLType(a)
  typeB = NLType(b)
  (a is b) or (
    if typeA.isList() and typeB.isList()
      a.length is b.length and a.every((elem, i) => @equality(elem, b[i]))
    else if typeA.isAgentSet() and typeB.isAgentSet()
      subsumes = (xs, ys) =>
        for x, index in xs
          if not equality(ys[index], x)
            return false
        true
      a.size() is b.size() and Object.getPrototypeOf(a) is Object.getPrototypeOf(b) and subsumes(a.sort(), b.sort())
    else
      typeA.isBreedSet(b.name) or typeB.isBreedSet(a.name) or
        (a is Nobody and b.isDead?()) or (b is Nobody and a.isDead?()) or ((typeA.isTurtle() or (typeA.isLink() and b isnt Nobody)) and a.compare(b) is EQ)
  )

perform = (options, primName, args) -> throw new Error("unimplemented perform stuff")

module.exports =

  class PrimsOuter

    _middle: undefined # PrimsMiddle

    primTypechecker: undefined

    # (RNGPrims, ListPrims) => PrimsOuter
    constructor: (@_rngPrims, @_listPrims) ->
      @_middle         = new PrimsMiddle(@_listPrims)
      @primTypechecker = new PrimTypechecker

    # (Any, Any) => Number
    add: (a, b) ->
      options = [
        [[NumberType, NumberType], -> a + b]
      ]
      perform(options, "+", [a, b])

    # (Any, Any) => Boolean
    and: (a, b) ->
      options = [
        [[BooleanType, BooleanType], -> a && b]
      ]
      perform(options, "and", [a, b])

    # () => Nothing
    boom: ->
      SimplePrims.boom()

    # (Any) => Array[_]|String
    butFirst: (xs) ->
      options = [
        [[ListType],   -> SimplePrims.butFirst_list(xs)],
        [[StringType], -> SimplePrims.butFirst_string(xs)]
      ]
      perform(options, "but-first", [xs])

    # (Any) => Array[_]|String
    butLast: (xs) ->
      options = [
        [[ListType],   -> SimplePrims.butLast_list(xs)],
        [[StringType], -> SimplePrims.butLast_string(xs)]
      ]
      perform(options, "but-last", [xs])

    # (Any, Any) => TurtleSet
    breedOn: (breedName, x) ->
      options = [
          [[PatchType],     -> SimplePrims.breedOn_string_patch(breedName, x)],
          [[PatchSetType],  -> SimplePrims.breedOn_string_patchset(breedName, x)],
          [[TurtleType],    -> SimplePrims.breedOn_string_turtle(breedName, x)],
          [[TurtleSetType], -> SimplePrims.breedOn_string_turtleset(breedName, x)]
        ]
      perform(options, "#{breedName}-on", [x])

    # (Any, Any) => Number
    divide: (a, b) ->
      options = [
        [[NumberType, NumberType], => @_middle.divide_number_number(a, b)]
      ]
      perform(options, "/", [a, b])

    # (Any) => Boolean
    empty: (xs) ->
      options = [
        [[ListType],   -> SimplePrims.empty_list(xs)],
        [[StringType], -> SimplePrims.empty_string(xs)]
      ]
      perform(options, "empty", [xs])

    # (Any, Any) => Boolean
    equality: (a, b) ->
      options = [
        [[WildcardType, WildcardType], -> equality(a, b)]
      ]
      perform(options, "=", [a, b])

    # (Any) => Any
    first: (xs) ->
      options = [
        [[ListType],   -> SimplePrims.first_list(xs)],
        [[StringType], -> SimplePrims.first_string(xs)]
      ]
      perform(options, "first", [xs])

    # [T] @ (T, Any) => Array[T]
    fput: (x, xs) ->
      options = [
        [[WildcardType, ListType], -> SimplePrims.fput_t_list(x, xs)]
      ]
      perform(options, "fput", [x, xs])

    # (Any, Any) => Boolean
    gt: (a, b) ->
      options = [
        [[StringType, StringType], -> SimplePrims.gt_string_string(a, b)],
        [[NumberType, NumberType], -> SimplePrims.gt_number_number(a, b)],
        [[AgentType,  AgentType],  -> SimplePrims.gt_comparable_comparable(a, b)]
      ]
      perform(options, ">", [a, b])

    # (Any, Any) => Boolean
    gte: (a, b) ->
      options = [
        [[StringType, StringType], -> SimplePrims.gt_string_string(a, b)         or equality(a, b)],
        [[NumberType, NumberType], -> SimplePrims.gt_number_number(a, b)         or equality(a, b)],
        [[AgentType,  AgentType],  -> SimplePrims.gt_comparable_comparable(a, b) or equality(a, b)]
      ]
      perform(options, ">=", [a, b])

    # (Any, Any) => Any
    item: (i, xs) ->
      options = [
        [[NumberType, ListType],   -> SimplePrims.item_number_list(i, xs)],
        [[NumberType, StringType], -> SimplePrims.item_number_string(i, xs)]
      ]
      perform(options, "item", [i, xs])

    # (Any) => Any
    last: (xs) ->
      options = [
        [[ListType],   -> SimplePrims.last_list(xs)],
        [[StringType], -> SimplePrims.last_string(xs)]
      ]
      perform(options, "last", [xs])

    # (Any) => Number
    length: (xs) ->
      options = [
        [[ListType],   -> SimplePrims.length_list(xs)],
        [[StringType], -> SimplePrims.length_string(xs)]
      ]
      perform(options, "length", [xs])

    # [T] @ (T*) => Array[T]
    list: (xs...) ->
      options = [
        [[TypeSet(WildcardType, false, true)], -> SimplePrims.list_ts(xs...)]
      ]
      perform(options, "list", [xs])

    # [T] @ (T, Any) => Array[T]
    lput: (x, xs) ->
      options = [
        [[WildcardType, ListType], -> SimplePrims.lput_t_list(x, xs)]
      ]
      perform(options, "lput", [x, xs])

    # (Any, Any) => Boolean
    lte: (a, b) ->
      options = [
        [[StringType, StringType], -> SimplePrims.lt_string_string(a, b)         or equality(a, b)],
        [[NumberType, NumberType], -> SimplePrims.lt_number_number(a, b)         or equality(a, b)],
        [[AgentType,  AgentType],  -> SimplePrims.lt_comparable_comparable(a, b) or equality(a, b)]
      ]
      perform(options, "<=", [a, b])

    # (Any, Any) => Boolean
    lt: (a, b) ->
      options = [
        [[StringType, StringType], -> SimplePrims.lt_string_string(a, b)],
        [[NumberType, NumberType], -> SimplePrims.lt_number_number(a, b)],
        [[AgentType,  AgentType],  -> SimplePrims.lt_comparable_comparable(a, b)]
      ]
      perform(options, "<", [a, b])

    # (Any) => Number
    max: (xs) ->
      options = [
        [[ListType], -> SimplePrims.max_list(xs)]
      ]
      perform(options, "max", [xs])

    # (Any) => Number
    mean: (xs) ->
      options = [
        [[ListType], -> SimplePrims.mean_list(xs)]
      ]
      perform(options, "mean", [xs])

    # (Any) => Number
    median: (xs) ->
      options = [
        [[ListType], => @_middle.median_list(xs)]
      ]
      perform(options, "median", [xs])

    # (Any, Any) => Boolean
    member: (x, xs) ->
      options = [
        [[WildcardType, ListType],     => @_listPrims.member_t_list(x, xs)],
        [[AgentType,    AgentSetType], -> SimplePrims.member_agent_agentset(x, xs)],
        [[StringType,   StringType],   -> SimplePrims.member_string_string(x, xs)]
      ]
      perform(options, "member?", [x, xs])

    # (Any) => Number
    min: (xs) ->
      options = [
        [[ListType], -> SimplePrims.min_list(xs)]
      ]
      perform(options, "min", [xs])

    # (Any, Any) => Number
    multiply: (a, b) ->
      options = [
        [[NumberType, NumberType], -> a * b]
      ]
      perform(options, "*", [a, b])

    # (Any, Any) => Array[_]|AbstractAgentSet[_]
    nOf: (n, xs) ->
      options = [
        [[NumberType, AgentSetType], => @_listPrims.nOf_number_agentset(n, xs)],
        [[NumberType, ListType],     => @_listPrims.nOf_number_list(n, xs)]
      ]
      perform(options, "n-of", [n, xs])

    # (Any) => Any
    oneOf: (xs) ->
      options = [
        [[AgentSetType], => @_listPrims.oneOf_agentset(xs)],
        [[ListType],     => @_listPrims.oneOf_list(xs)]
      ]
      perform(options, "one-of", [xs])

    # (Any, Any) => Boolean
    or: (a, b) ->
      options = [
        [[BooleanType, BooleanType], -> a || b]
      ]
      perform(options, "or", [a, b])

    # (Any, Any) => Number|Boolean
    position: (x, xs) ->
      options = [
        [[WildcardType, ListType],   => @_listPrims.position_t_list(x, xs)],
        [[StringType,   StringType], -> SimplePrims.position_string_string(x, xs)]
      ]
      perform(options, "position", [x, xs])

    # (Any) => Number
    random: (n) ->
      options = [
        [[NumberType], => @_rngPrims.random_number(n)]
      ]
      perform(options, "random", [n])

    # (Any) => Number
    randomFloat: (n) ->
      options = [
        [[NumberType], => @_rngPrims.randomFloat_number(n)]
      ]
      perform(options, "random-float", [n])

    # (Any, Any) => Number
    remainder: (a, b) ->
      options = [
        [[NumberType, NumberType], => @_middle.remainder_number_number(a, b)]
      ]
      perform(options, "remainder", [a, b])

    # (Any, Any) => Array[_]|String
    remove: (x, xs) ->
      options = [
        [[WildcardType, ListType],   => @_listPrims.remove_t_list(x, xs)],
        [[StringType,   StringType], -> SimplePrims.remove_string_string(x, xs)]
      ]
      perform(options, "remove", [x, xs])

    # (Any) => Array[_]
    removeDuplicates: (xs) ->
      options = [
        [[ListType], => @_listPrims.removeDuplicates_list(xs)]
      ]
      perform(options, "remove-duplicates", [xs])

    # (Any, Any) => Array[_]|String
    removeItem: (i, xs) ->
      options = [
        [[NumberType, ListType],   -> SimplePrims.removeItem_number_list(i, xs)],
        [[NumberType, StringType], -> SimplePrims.removeItem_number_string(i, xs)]
      ]
      perform(options, "remove-item", [i, xs])

    # (Any) => Array[_]
    reverse: (xs) ->
      options = [
        [[ListType], -> SimplePrims.revserse_list(xs)]
      ]
      perform(options, "reverse", [xs])

    # (Any*) => Array[_]
    sentence: (xs...) ->
      options = [
        [[TypeSet(WildcardType, false, true)], -> SimplePrims.sentence_listOrTs(xs...)]
      ]
      perform(options, "sentence", [xs])

    # (Any) => Array[_]
    sort: (xs) ->
      options = [
        [[ListType], => @_middle.sort_list(xs)]
      ]
      perform(options, "sort", [xs])

    # (Any) => Number
    standardDeviation: (xs) ->
      options = [
        [[ListType], => @_middle.standardDeviation_list(xs)]
      ]
      perform(options, "standard-deviation", [xs])

    # [T] @ (Any, Any, Any) => Array[T]
    sublist: (xs, n1, n2) ->
      options = [
        [[ListType, NumberType, NumberType], -> SimplePrims.sublist_list_number_number(xs, n1, n2)]
      ]
      perform(options, "sublist", [xs, n1, n2])

    # (Any, Any, Any) => String
    substring: (str, n1, n2) ->
      options = [
        [[StringType, NumberType, NumberType], -> SimplePrims.substring_list_number_number(str, n1, n2)]
      ]
      perform(options, "substring", [str, n1, n2])

    # (Any, Any) => Boolean
    subtract: (a, b) ->
      options = [
        [[NumberType, NumberType], -> a - b]
      ]
      perform(options, "-", [a, b])

    # (Any) => Number
    sum: (xs) ->
      options = [
        [[ListType], => @_middle.sum_list(xs)]
      ]
      perform(options, "sum", [xs])

    # (Any) => TurtleSet
    turtlesOn: (x) ->
      options = [
        [[PatchType],     -> SimplePrims.turtlesOn_patch(x)],
        [[PatchSetType],  -> SimplePrims.turtlesOn_patchset(x)],
        [[TurtleType],    -> SimplePrims.turtlesOn_turtle(x)],
        [[TurtleSetType], -> SimplePrims.turtlesOn_turtleset(x)]
      ]
      perform(options, "turtles-on", [x])

    # (Any) => Number
    variance: (xs) ->
      options = [
        [[ListType], => @_middle.variance_list(xs)]
      ]
      perform(options, "variance", [xs])

    # (Any, Any) => Boolean
    xor: (a, b) ->
      options = [
        [[BooleanType, BooleanType], -> a != b]
      ]
      perform(options, "xor", [a, b])
