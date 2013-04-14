/*
  Copyright (c) 2009-2013, Ian Martins (ianxm@jhu.edu)

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
*/

package ihx;

using StringTools;
import neko.Lib;
import ihx.program.Program;

enum CmdError
{
    IncompleteStatement;
    InvalidStatement(msg :String);
}

class CmdProcessor
{
    /** accumulating command fragments */
    private var sb :StringBuf;
  
    /** hash connecting interpreter commands to the functions that implement them */
    private var commands :Hash<Dynamic>;

    /** controls temp program text */
    private var program :Program;

    /** name of new lib to include in build */
    private var cmdStr :String;

    public function new()
    {
        program = new Program();
        sb = new StringBuf();
        commands = new Hash<Void->String>();
        commands.set("dir", listVars);
        commands.set("addlib", addLib);
        commands.set("rmlib", rmLib);
        commands.set("libs", listLibs);
        commands.set("clear", clearVars);
        commands.set("print", printProgram);
        commands.set("help", printHelp);
        commands.set("exit", callback(neko.Sys.exit,0));
        commands.set("quit", callback(neko.Sys.exit,0));
    }

    /**
       process a line of user input
    **/
    public function process(cmd :String) :String
    {
        if( cmd.endsWith("\\") )
        {
            sb.add(cmd.substr(0, cmd.length-1));
            throw IncompleteStatement;
        }

        sb.add(cmd);
        var ret;
        try
        {
            cmdStr = sb.toString();
            var cmd = firstWord(cmdStr);
            if( commands.exists(cmd) )                      // handle ihx commands
                ret = commands.get(cmd)();
            else                                            // execute a haxe statement
            {
                program.addStatement(cmdStr);
                ret = NekoEval.evaluate(program.getProgram());
                program.acceptLastCmd(true);
            }
        }
        catch (ex :String)
        {
            program.acceptLastCmd(false);
            sb = new StringBuf();
            throw InvalidStatement(ex);
        }

        sb = new StringBuf();
        return (ret==null) ? null : Std.string(ret);
    }

    private function firstWord(str :String) :String
    {
        var space = str.indexOf(" ");
        if( space == -1 )
            return str;
        return str.substr(0, space);
    }
                
    /**
       return a list of all user defined variables
    **/
    private function listVars() :String
    {
        var vars = program.getVars();
        if( vars.isEmpty() )
            return "vars: (none)\n";
        return wordWrap("vars: "+ vars.join(", ") +"\n");
    }

    /**
       add a haxelib library to the compile command
    **/
    private function addLib() :String
    {
        var name = cmdStr.split(" ")[1];
        if( name==null || name.length==0 )
            return "syntax error\n";
        NekoEval.libs.add(name);
        return "added: " + name +"\n";
    }

    /**
       remove a haxelib library from the compile command
    **/
    private function rmLib() :String
    {
        var name = cmdStr.split(" ")[1];
        if( name == null || name.length==0 )
            return "syntax error\n";
        NekoEval.libs.remove(function(ii) return ii==name);
        return "removed: " + name +"\n";
    }

    /**
       list haxelib libraries
    **/
    private function listLibs() :String
    {
        if( NekoEval.libs.length == 0 )
            return "libs: (none)\n";
        return "libs: " + wordWrap(Lambda.list(NekoEval.libs).join(", ") +"\n");
    }

    /**
       reset workspace
    **/
    private function clearVars() :String
    {
        program = new Program();
        return "cleared\n";
    }

    /**
       print temp program
    **/
    private function printProgram() :String
    {
        return program.getProgram();
    }

    private function wordWrap(str :String) :String
    {
        if( str.length<=80 )
            return str;
    
        var words :Array<String> = str.split(" ");
        var sb = new StringBuf();
        var ii = 0; // index of current word
        var oo = 1; // index of current output line
        while( ii<words.length )
        {
            while( ii<words.length && sb.toString().length+words[ii].length+1<80*oo )
            {
                if( ii!=0 )
                    sb.add(" ");
                sb.add(words[ii]);
                ii++;
            }
            if( ii<words.length )
            {
                sb.add("\n    ");
                oo++;
            }
        }

        return sb.toString();
    }

    private function printHelp() :String
    {
        return "ihx shell commands:\n"
            + "  dir            list all currently defined variables\n"
            + "  addlib [name]  add a haxelib library to the search path\n"
            + "  rmlib  [name]  remove a haxelib library from the search path\n"
            + "  libs           list haxelib libraries that have been added\n"
            + "  clear          delete all variables from the current session\n"
            + "  print          dump the temp neko program to the console\n"
            + "  help           print this message\n"
            + "  exit           close this session\n"
            + "  quit           close this session";
    }
}
