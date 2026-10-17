package macro;

import haxe.macro.Compiler;
import haxe.io.Path;
import haxe.macro.Expr;
import haxe.macro.Context;

using haxe.macro.PositionTools;

class Macro {
    macro public static function checkCPP() {
        if (!Context.defined("cpp"))
            Context.fatalError("[HxSysInfo] HxSysInfo is only available in C++ target.", ((macro null).pos));
        if (Context.defined("linux") && !Context.defined("NO_PRECOMPILED_HEADERS")) // causes hxcpp to freak the fuck out on linux
            Compiler.define("NO_PRECOMPILED_HEADERS");

        return macro null;
    }

    macro public static function xml(_lib:String, _relative_root:String='../'):Array<Field> {
        var _pos =  Context.currentPos();
        var _pos_info = _pos.getInfos();
        var _class = Context.getLocalClass();

        var _source_path = Path.directory(_pos_info.file);
        if( !Path.isAbsolute(_source_path) ) {
            _source_path = Path.join([Sys.getCwd(), _source_path]);
        }

        _source_path = Path.normalize(_source_path);

        var _lib_path = Path.normalize(Path.join([_source_path, _relative_root]));
        var _lib_var = '${_lib.toUpperCase()}_HXSYSINFO_PATH';

        var _define = '<set name="$_lib_var" value="$_lib_path/"/>';
        var _import_path = '$${$_lib_var}/Build.xml';
        var _import = '<include name="$_import_path" />';

        _class.get().meta.add(":buildXml", [{ expr:EConst( CString( '$_define\n$_import' ) ), pos:_pos }], _pos );
        return Context.getBuildFields();
    }
}