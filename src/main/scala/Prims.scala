// (C) Uri Wilensky. https://github.com/NetLogo/NetLogo

package org.nlogo.tortoise

import org.nlogo.{ api, compile => ast, nvm, prim }

object Prims {

  def reporter(r: ast.ReporterApp): String = {
    def arg(i: Int) = Handlers.reporter(r.args(i))
    def commaArgs = argsSep(", ")
    def args =
      r.args.collect{ case x: ast.ReporterApp => Handlers.reporter(x) }
    def argsSep(sep: String) =
      args.mkString(sep)
    r.reporter match {
      case SimplePrims.SimpleReporter(op)   => op
      case SimplePrims.InfixReporter(op)    => s"(${arg(0)} $op ${arg(1)})"
      case SimplePrims.NormalReporter(op)   => s"$op($commaArgs)"
      case x: prim.etc._isbreed             => s"""${arg(0)}.isBreed("${x.breedName}")"""
      case b: prim.etc._breed               => s"""world.turtlesOfBreed("${b.getBreedName}")"""
      case b: prim.etc._breedsingular       => s"""world.getTurtleOfBreed("${b.breedName}", ${arg(0)})"""
      case b: prim.etc._breedhere           => s"""AgentSet.self().breedHere("${b.getBreedName}")"""
      case pure: nvm.Pure if r.args.isEmpty => Handlers.literal(pure.report(null))
      case lv: prim._letvariable            => Handlers.ident(lv.let.name)
      case pv: prim._procedurevariable      => Handlers.ident(pv.name)
      case call: prim._callreport           => s"${Handlers.ident(call.procedure.name)}($commaArgs)"
      case _: prim._unaryminus              => s"(- ${arg(0)})"
      case bv: prim._breedvariable          => s"""AgentSet.getBreedVariable("${bv.name}")"""
      case tv: prim._turtlevariable         => s"AgentSet.getTurtleVariable(${tv.vn})"
      case tv: prim._linkvariable           => s"AgentSet.getLinkVariable(${tv.vn})"
      case tv: prim._turtleorlinkvariable   =>
        val vn = api.AgentVariables.getImplicitTurtleVariables.indexOf(tv.varName)
        s"AgentSet.getTurtleVariable($vn)"
      case pv: prim._patchvariable          => s"AgentSet.getPatchVariable(${pv.vn})"
      case r: prim._reference               => s"${r.reference.vn}"
      case ov: prim._observervariable       => s"Globals.getGlobal(${ov.vn})"
      case _: prim._word                    =>
        ("\"\"" +: args).map(arg => "Dump(" + arg + ")").mkString("(", " + ", ")")
      case _: prim._with =>
        val agents = arg(0)
        val filter = Handlers.reporter(r.args(1))
        s"AgentSet.agentFilter($agents, ${Handlers.fun(r.args(1), true)})"
      case _: prim._of =>
        val agents = arg(1)
        val body = Handlers.reporter(r.args(0))
        s"AgentSet.of($agents, ${Handlers.fun(r.args(0), true)})"
      case o: prim.etc._all =>
        val agents = arg(0)
        val body = Handlers.reporter(r.args(1))
        s"AgentSet.all($agents, function(){ return $body })"
      case _: prim.etc._islink              => s"(${arg(0)} instanceof Link)"
      case _ =>
        throw new IllegalArgumentException(
          "unknown primitive: " + r.reporter.getClass.getName)
    }
  }

  def generateCommand(s: ast.Statement): String = {
    def arg(i: Int) = Handlers.reporter(s.args(i))
    def args =
      s.args.collect{ case x: ast.ReporterApp =>
        Handlers.reporter(x) }.mkString(", ")
    s.command match {
      case SimplePrims.SimpleCommand(op) => if (op.isEmpty) "" else s"$op;"
      case SimplePrims.NormalCommand(op) => s"$op($args);"
      case _: prim._set                  => generateSet(s)
      case _: prim._repeat               => generateRepeat(s)
      case _: prim.etc._while            => generateWhile(s)
      case _: prim.etc._if               => generateIf(s)
      case _: prim.etc._ifelse           => generateIfElse(s)
      case _: prim._ask                  => generateAsk(s, shuffle = true)
      case _: prim._createturtles        => generateCreateTurtles(s, ordered = false)
      case _: prim._createorderedturtles => generateCreateTurtles(s, ordered = true)
      case _: prim._sprout               => generateSprout(s)
      case _: prim.etc._createlinkfrom   => generateCreateLink(s, "createLinkFrom")
      case _: prim.etc._createlinksfrom  => generateCreateLink(s, "createLinksFrom")
      case _: prim.etc._createlinkto     => generateCreateLink(s, "createLinkTo")
      case _: prim.etc._createlinksto    => generateCreateLink(s, "createLinksTo")
      case _: prim.etc._createlinkwith   => generateCreateLink(s, "createLinkWith")
      case _: prim.etc._createlinkswith  => generateCreateLink(s, "createLinksWith")
      case h: prim._hatch                => generateHatch(s, h.breedName)
      case call: prim._call              => s"${Handlers.ident(call.procedure.name)}($args);"
      case _: prim.etc._report           => s"return $args;"
      case l: prim._let                  =>
        // arg 0 is the name but we don't access it because LetScoper took care of it.
        // arg 1 is the value.
        s"var ${Handlers.ident(l.let.name)} = ${arg(1)};"
      case _ =>
        throw new IllegalArgumentException(
          "unknown primitive: " + s.command.getClass.getName)
    }
  }

  /// custom generators for particular Commands

  def generateSet(s: ast.Statement): String = {
    def arg(i: Int) = Handlers.reporter(s.args(i))
    s.args(0).asInstanceOf[ast.ReporterApp].reporter match {
      case p: prim._letvariable =>
        s"${Handlers.ident(p.let.name)} = ${arg(1)};"
      case p: prim._observervariable =>
        s"Globals.setGlobal(${p.vn}, ${arg(1)});"
      case bv: prim._breedvariable =>
        s"""AgentSet.setBreedVariable("${bv.name}", ${arg(1)});"""
      case p: prim._linkvariable =>
        s"AgentSet.setLinkVariable(${p.vn}, ${arg(1)});"
      case p: prim._turtlevariable =>
        s"AgentSet.setTurtleVariable(${p.vn}, ${arg(1)});"
      case p: prim._turtleorlinkvariable if p.varName == "BREED" =>
        s"AgentSet.setBreed(${arg(1)});"
      case p: prim._turtleorlinkvariable =>
        val vn = api.AgentVariables.getImplicitTurtleVariables.indexOf(p.varName)
        s"AgentSet.setTurtleVariable($vn, ${arg(1)});"
      case p: prim._patchvariable =>
        s"AgentSet.setPatchVariable(${p.vn}, ${arg(1)});"
      case p: prim._procedurevariable =>
        s"${Handlers.ident(p.name)} = ${arg(1)};"
      case x =>
        throw new IllegalArgumentException(
          "unknown settable: " + x.getClass.getName)
    }
  }

  def generateRepeat(w: ast.Statement): String = {
    val count = Handlers.reporter(w.args(0))
    val body = Handlers.commands(w.args(1))
    s"""|Prims.repeat($count, function () {
        |${Handlers.indented(body)}
        |});""".stripMargin
  }

  def generateWhile(w: ast.Statement): String = {
    val pred = Handlers.reporter(w.args(0))
    val body = Handlers.commands(w.args(1))
    s"""|while ($pred) {
        |${Handlers.indented(body)}
        |}""".stripMargin
  }

  def generateIf(s: ast.Statement): String = {
    val pred = Handlers.reporter(s.args(0))
    val body = Handlers.commands(s.args(1))
    s"""|if ($pred) {
        |${Handlers.indented(body)}
        |}""".stripMargin
  }

  def generateIfElse(s: ast.Statement): String = {
    val pred      = Handlers.reporter(s.args(0))
    val thenBlock = Handlers.commands(s.args(1))
    val elseBlock = Handlers.commands(s.args(2))
    s"""|if ($pred) {
        |${Handlers.indented(thenBlock)}
        |}
        |else {
        |${Handlers.indented(elseBlock)}
        |}""".stripMargin
  }

  def generateAsk(s: ast.Statement, shuffle: Boolean): String = {
    val agents = Handlers.reporter(s.args(0))
    val body = Handlers.fun(s.args(1))
    s"AgentSet.ask($agents, $shuffle, $body);"
  }

  def generateCreateLink(s: ast.Statement, name: String): String = {
    import org.nlogo.prim._
    val other = Handlers.reporter(s.args(0))
    // This is so that we don't shuffle unnecessarily.  FD 10/31/2013
    val nonEmptyCommandBlock =
      s.args(1).asInstanceOf[ast.CommandBlock]
        .statements.stmts.nonEmpty
    val body = Handlers.fun(s.args(1))
    s"""AgentSet.ask(AgentSet.$name($other), $nonEmptyCommandBlock, $body);"""
  }

  def generateCreateTurtles(s: ast.Statement, ordered: Boolean): String = {
    import org.nlogo.prim._
    val n = Handlers.reporter(s.args(0))
    val name = if (ordered) "createOrderedTurtles" else "createTurtles"
    val breed =
      s.command match {
        case x: _createturtles => x.breedName
        case x: _createorderedturtles => x.breedName
        case x => throw new IllegalArgumentException("How did you get here with class of type " + x.getClass.getName)
      }
    val body = Handlers.fun(s.args(1))
    s"""AgentSet.ask(world.$name($n, "$breed"), true, $body);"""
  }

  def generateSprout(s: ast.Statement): String = {
    val n = Handlers.reporter(s.args(0))
    val body = Handlers.fun(s.args(1))
    val breedName = s.command.asInstanceOf[prim._sprout].breedName
    s"""AgentSet.ask(Prims.sprout($n, "$breedName"), true, $body);"""
  }

  def generateHatch(s: ast.Statement, breedName: String): String = {
    val n = Handlers.reporter(s.args(0))
    val body = Handlers.fun(s.args(1))
    s"""AgentSet.ask(Prims.hatch($n, "$breedName"), true, $body);"""
  }

}