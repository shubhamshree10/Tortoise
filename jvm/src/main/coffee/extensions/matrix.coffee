{ find, map   } = require('brazierjs/array')
{ arrayEquals } = require('brazierjs/equals')
{ pipeline    } = require('brazierjs/function')
{ fold        } = require('brazierjs/maybe')
{ rangeUntil  } = require('brazierjs/number')
StrictMath      = require('shim/strictmath')
{ Matrix      } = require('vectorious/withoutblas')

# Matrix => String
dumpMatrix = (matrix) ->
  inner = matrix.toArray().map((row) -> "[ #{row.join(" ")} ]").join("")
  " [ #{inner} ]"

# Any => Boolean
isMatrix = (x) ->
  x instanceof Matrix

module.exports = {

  dumper: { canDump: isMatrix, dump: (x) -> "{{matrix: #{dumpMatrix(x)}}}" }

  init: (workspace) ->

    # (Number, Number, Number) => Matrix
    makeConstant = (rows, cols, initialValue) ->
      Matrix.fill(rows, cols, initialValue)

    # Number => Matrix
    makeIdentity = (size) ->
      Matrix.identity(size)

    # List[List[Number]] => Matrix
    fromRowList = (nestedList) ->
      new Matrix(nestedList)

    # List[List[Number]] => Matrix
    fromColumnList = (nestedList) ->
      (new Matrix(nestedList)).T

    # Matrix => List[List[Number]]
    toRowList = (matrix) ->
      matrix.toArray()

    # Matrix => List[List[Number]]
    toColumnList = (matrix) ->
      matrix.T.toArray()

    # Matrix => Matrix
    copy = (matrix) ->
      new Matrix(matrix.toArray())

    # Matrix => String
    prettyPrint = (matrix) ->

      [rows, cols] = matrix.shape
      itemStrs     = pipeline(rangeUntil(0), map(-> []))(rows)
      longest      = pipeline(rangeUntil(0), map(->  0))(cols)

      matrix.each(
        (item, i, j) ->
          str            = item.toString()
          len            = str.length
          itemStrs[i][j] = str
          if len > longest[j]
            longest[j] = len
      )

      alignRow = (row) ->
        row.map(
          (str, j) ->
            padSize = longest[j] - str.length
            pad     = Array(padSize + 1).join(' ')
            pad.concat(str)
        ).join('  ')

      aligned = itemStrs.map((row) -> "[ #{alignRow(row)} ]").join('\n ')

      "[#{aligned}]"

    # (Matrix, Number, Number) => Number
    get = (matrix, i, j) ->
      matrix.get(i, j)

    # (Matrix, Number) => List[Number]
    getRow = (matrix, i) ->
      [_, cols] = matrix.shape
      rangeUntil(0)(cols).map((j) -> matrix.get(i, j))

    # (Matrix, Number) => List[Number]
    getColumn = (matrix, j) ->
      [rows, _] = matrix.shape
      rangeUntil(0)(rows).map((i) -> matrix.get(i, j))

    # (Matrix, Number, Number, Number) => Unit
    set = (matrix, i, j, newVal) ->
      matrix.set(i, j, newVal)
      return

    # (Matrix, Number, Number) => Unit
    setRow = (matrix, i, newVals) ->
      [_, cols] = matrix.shape
      rangeUntil(0)(cols).forEach((j) -> matrix.set(i, j, newVals[j]))
      return

    # (Matrix, Number, Number) => Unit
    setColumn = (matrix, j, newVals) ->
      [rows, _] = matrix.shape
      rangeUntil(0)(rows).forEach((i) -> matrix.set(i, j, newVals[i]))
      return

    # (Matrix, Number, Number) => Unit
    swapRows = (matrix, r1, r2) ->
      matrix.swap(r1, r2)
      return

    # (Matrix, Number, Number) => Unit
    swapColumns = (matrix, c1, c2) ->
      [rows, _] = matrix.shape
      for i in rangeUntil(0)(rows)
        oldC1 = matrix.get(i, c1)
        matrix.set(i, c1, matrix.get(i, c2))
        matrix.set(i, c2, oldC1)
      return

    # (Matrix, Number, Number, Number) => Matrix
    setAndReport = (matrix, i, j, newVal) ->
      dupe = copy(matrix)
      set(dupe, i, j, newVal)
      dupe

    # (Matrix) => (Number, Number)
    dimensions = (matrix) ->
      matrix.shape

    # (Matrix, Number, Number, Number, Number) => Matrix
    submatrix = (matrix, r1, c1, r2, c2) ->

      (-> # Error-checking blurb

        [numRows, numCols] = matrix.shape

        checkArg = ({ arg, lower, upper, isStart, isRow }) ->
          if not (lower <= arg <= upper)
            polarity  = if isStart then "Start" else "End"
            dimName   = if isRow   then "row"   else "column"
            complaint = "Extension exception: #{polarity} #{dimName} index (#{arg}) is invalid."
            remedy    = "Should be between #{lower} and #{upper} inclusive."
            throw new Error("#{complaint}  #{remedy}")

        [{ arg: r1, lower: 0, upper: numRows - 1, isStart:  true, isRow:  true }
        ,{ arg: c1, lower: 0, upper: numCols - 1, isStart:  true, isRow: false }
        ,{ arg: r2, lower: 1, upper: numRows    , isStart: false, isRow:  true }
        ,{ arg: c2, lower: 1, upper: numCols    , isStart: false, isRow: false }].forEach(checkArg)

      )()

      arr     = matrix.toArray()
      subRows = r2 - r1
      subCols = c2 - c1
      subArr  = pipeline(rangeUntil(0), map(-> []))(subRows)

      for i in rangeUntil(0)(subRows)
        for j in rangeUntil(0)(subCols)
          subArr[i][j] = arr[r1 + i][c1 + j]

      new Matrix(subArr)

    # ((Number* => Number), Matrix, Matrix*) => Matrix
    matrixMap = (reporter, matrix, rest...) ->

      if reporter.length > rest.length + 1
        throw new Error("Extension exception: Task expected #{reporter.length} matrix inputs but only got #{rest.length + 1}.")

      for m in rest
        if not arrayEquals(matrix.shape)(m.shape)
          shapeToStr = ([x, y]) -> "#{x}x#{y}"
          firstShape = shapeToStr(matrix.shape)
          badShape   = shapeToStr(m.shape)
          throw new Error("Extension exception: All matrices must have the same dimensions: the first was #{firstShape} and another was #{badShape}.")

      matrix.map(
        (item, i, j) ->
          restItems = rest.map((m) -> m.get(i, j))
          reporter(item, restItems...)
      )

    # ((Number, Number) => Number, (Matrix, Matrix) => Matrix, (Matrix, Number) => Matrix) =>
    #   (Matrix|Number, Matrix|Number, (Matrix|Number)*) =>
    #     Matrix|Number
    opReducer = (scalarOp, matrixOp, mixedOp) ->
      (m1, m2, rest...) ->
        [m1, m2, rest...].reduce(
          (left, right) ->
            if workspace.typechecker(left).isNumber()
              if workspace.typechecker(right).isNumber()
                scalarOp(left, right)
              else
                mixedOp(right, left)
            else
              if workspace.typechecker(right).isNumber()
                mixedOp(left, right)
              else
                matrixOp(left, right)
        )

    # (Matrix|Number, Matrix|Number, (Matrix|Number)*) => Matrix|Number
    times = (m1, m2, rest...) ->
      opReducer(((s1, s2) => s1 * s2), Matrix.multiply, Matrix.scale)(m1, m2, rest...)

    # (Matrix, Matrix, Matrix*) => Matrix
    timesElementWise = (m1, m2, rest...) ->
      opReducer(((s1, s2) => s1 * s2), Matrix.product, Matrix.scale)(m1, m2, rest...)

    # (Matrix|Number, Matrix|Number, (Matrix|Number)*) => Matrix|Number
    plus = (m1, m2, rest...) ->
      opReducer(((s1, s2) => s1 + s2), Matrix.add, ((m, s) -> m.map((x) -> x + s)))(m1, m2, rest...)

    # (Matrix|Number, Matrix|Number, (Matrix|Number)*) => Matrix|Number
    minus = (m1, m2, rest...) ->
      operands          = [m1, m2, rest...]
      [rows, cols]      = pipeline(find(isMatrix), fold(-> throw new Error("One or more (-) operands must be a matrix..."))((x) -> x.shape))(operands)
      broadcastIfNumber = (x) -> if workspace.typechecker(x).isNumber() then Matrix.fill(rows, cols, x) else x
      operands.reduce((left, right) -> Matrix.subtract(broadcastIfNumber(left), broadcastIfNumber(right)))

    # Matrix => Matrix
    inverse = (matrix) ->
      matrix.inverse()

    # Matrix => Matrix
    transpose = (matrix) ->
      matrix.T

    # Apparently this is inefficient for large matrices. --SL (Spring, 2017)
    # Matrix => Number
    det = (matrix) ->
      matrix.determinant()

    # Matrix => Number
    rank = (matrix) ->
      matrix.rank()

    # Matrix => Number
    trace = (matrix) ->
      matrix.trace()

    # (Matrix, Matrix) => Matrix
    solve = (m1, m2) ->
      m1.solve(m2)

    # List[Number] => (Number, Number, Number, Number)
    forecastGrowthHelper = (data) ->
      indepVar                  = rangeUntil(0)(data.length)
      dataMatrix                = fromColumnList([data, indepVar])
      [[constant, slope], [r2]] = regress(dataMatrix)
      [constant, slope, r2]

    # List[Number] => (Number, Number, Number, Number)
    forecastLinearGrowth = (data) ->
      [constant, slope, r2] = forecastGrowthHelper(data)
      forecast              = slope * data.length + constant
      [forecast, constant, slope, r2]

    # List[Number] => (Number, Number, Number, Number)
    forecastCompoundGrowth = (data) ->
      lnData     = data.map(StrictMath.log)
      [c, p, r2] = forecastGrowthHelper(lnData)
      constant   = StrictMath.exp(c)
      proportion = StrictMath.exp(p)
      forecast   = constant * proportion ** data.length
      [forecast, constant, proportion, r2]

    # List[Number] => (Number, Number, Number, Number)
    forecastContinuousGrowth = (data) ->
      lnData        = data.map(StrictMath.log)
      [c, rate, r2] = forecastGrowthHelper(lnData)
      constant      = StrictMath.exp(c)
      forecast      = constant * StrictMath.exp(rate * data.length)
      [forecast, constant, rate, r2]

    # Matrix => (List[Number], (Number, Number, Number))
    regress = (data) ->

      y = fromColumnList([getColumn(data, 0)])

      # To construct the matrix (known as "matrix" in the code, and as "X" in the comments),
      # we replace the first column (the dependent variable) of the input matrix with all 1's --SL (Spring, 2017)
      [nObservations, nVars] = data.shape
      indepVars              = submatrix(data, 0, 1, nObservations, nVars)
      ones                   = y.map(-> 1)
      matrix                 = Matrix.augment(ones, indepVars)

      # Solve the system Xb = y for b, the row vector of coefficients for each independent variable.
      # The following form ensures X does not need to be square: y.T * X * (X.T * X)^-1 --SL (Spring, 2017)
      coefficients = times(y.T, matrix, inverse(times(matrix.T, matrix)))

      ySum       = y.reduce((a, b) -> a + b)
      yBar       = ySum / nObservations
      yDiff      = minus(y, Matrix.fill(nObservations, 1, yBar))
      totalSumSq = times(yDiff.T, yDiff).get(0, 0)

      resid      = minus(times(matrix, coefficients.T), y)
      residSumSq = times(resid.T, resid).get(0, 0)

      rSquared = 1 - (residSumSq / totalSumSq)
      stats    = [rSquared, totalSumSq, residSumSq]

      [getRow(coefficients, 0), stats]

    {
      name: "matrix"
    , prims: {
        "MAKE-CONSTANT":              makeConstant
      , "MAKE-IDENTITY":              makeIdentity
      , "FROM-ROW-LIST":              fromRowList
      , "FROM-COLUMN-LIST":           fromColumnList
      , "TO-ROW-LIST":                toRowList
      , "TO-COLUMN-LIST":             toColumnList
      , "COPY":                       copy
      , "PRETTY-PRINT-TEXT":          prettyPrint
      , "SOLVE":                      solve
      , "GET":                        get
      , "GET-ROW":                    getRow
      , "GET-COLUMN":                 getColumn
      , "SET":                        set
      , "SET-ROW":                    setRow
      , "SET-COLUMN":                 setColumn
      , "SWAP-ROWS":                  swapRows
      , "SWAP-COLUMNS":               swapColumns
      , "SET-AND-REPORT":             setAndReport
      , "DIMENSIONS":                 dimensions
      , "SUBMATRIX":                  submatrix
      , "MAP":                        matrixMap
      , "TIMES-SCALAR":               times
      , "TIMES":                      times
      , "*":                          times
      , "TIMES-ELEMENT-WISE":         timesElementWise
      , "PLUS-SCALAR":                plus
      , "PLUS":                       plus
      , "+":                          plus
      , "MINUS":                      minus
      , "-":                          minus
      , "INVERSE":                    inverse
      , "TRANSPOSE":                  transpose
      , "DET":                        det
      , "RANK":                       rank
      , "TRACE":                      trace
      , "FORECAST-LINEAR-GROWTH":     forecastLinearGrowth
      , "FORECAST-COMPOUND-GROWTH":   forecastCompoundGrowth
      , "FORECAST-CONTINUOUS-GROWTH": forecastContinuousGrowth
      , "REGRESS":                    regress
      , "IS-MATRIX?":                 isMatrix
      }
    }

}