# (C) Uri Wilensky. https://github.com/NetLogo/Tortoise

define(['util/exception'], (Exception) ->

  class Ticker

    # Number
    _count: undefined

    # ((String*) => Unit) => Ticker
    constructor: (@_updateFunc) ->
      @_count = -1

    # () => Unit
    reset: ->
      @_updateTicks(-> 0)
      return

    # () => Unit
    clear: ->
      @_updateTicks(-> -1)
      return

    # () => Unit
    tick: ->
      if @_count is -1
        throw new Exception.NetLogoException("The tick counter has not been started yet. Use RESET-TICKS.")
      else
        @_updateTicks((counter) -> counter + 1)
      return

    # (Number) => Unit
    tickAdvance: (n) ->
      if @_count is -1
        throw new Exception.NetLogoException("The tick counter has not been started yet. Use RESET-TICKS.")
      else if n < 0
        throw new Exception.NetLogoException("Cannot advance the tick counter by a negative amount.")
      else
        @_updateTicks((counter) -> counter + n)
      return

    # () => Number
    tickCount: ->
      if @_count is -1
        throw new Exception.NetLogoException("The tick counter has not been started yet. Use RESET-TICKS.")
      @_count

    # ((Number) => Number) => Unit
    _updateTicks: (updateCountFunc) ->
      @_count = updateCountFunc(@_count)
      @_updateFunc("ticks")
      return

)
