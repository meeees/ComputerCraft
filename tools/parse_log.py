import json
import tokenize
import token
from io import BytesIO

with open("crafttweaker.log", "r") as f:
    dat = f.read()

recipe_types = dat.split('Recipe type: ')[1:]

def pull_tokens(s, tokenList):
    ret = []
    for i in range(0, len(tokenList) - 1):
        t = tokenList[i]
        s = s[s.find(t)+len(t):]
        ret.append(s[:s.find(tokenList[i+1])])
    return ret

def detag(s):
    return s[1:-1]

def untokenize(l):
    return tokenize.untokenize(l).decode('utf-8')

def tags_to_strs(args):
    token_iter = tokenize.tokenize(BytesIO(args.encode('utf-8')).readline)
    results = []
    in_tag = False
    tagval = ""
    # Make tags strings
    for toknum, tokval, _, _, _ in token_iter:
        if in_tag:
            if toknum == token.OP and tokval == '>':
                in_tag = False
                results.append((token.STRING, '"%s"' % tagval))
                tagval = ""
                continue
            else:
                tagval += tokval
                continue
        if toknum == token.OP and tokval == '<':
            in_tag = True
            continue
        results.append((toknum, tokval))
    return untokenize(results)

def get_lists(token_stream, start, end, sep=',', potential_new='([{', potential_end=')]}', in_list=False, top_level=True, only_list=False, to_remove=[token.NL]):
    #print('enter get_lists with ', start, end, in_list)
    results = []
    current = []
    entry = []
    while True:
        toknum, tokval, _, _, _ = next(token_stream)
        if toknum in to_remove:
            continue
        #print(token.tok_name[toknum], tokval, in_list, top_level)
        if in_list:
            if toknum == token.OP and tokval == end:
                if len(entry) == 1:
                    current.extend(entry)
                else:
                    current.append(entry)
                in_list = False
                if top_level and not only_list:
                    results.append(current)
                else:
                    results.extend(current)
                #print('exit get_lists ', end, results)
                return results
            elif toknum == token.OP and tokval == sep:
                if len(entry) == 1:
                    current.extend(entry)
                else:
                    current.append(entry)
                entry = []
            elif toknum == token.OP and tokval in potential_new:
                i = potential_new.find(tokval)
                r = get_lists(token_stream, potential_new[i], potential_end[i], sep, potential_new, potential_end, True, False)
                if len(r) == 1:
                    entry.extend(r)
                else:
                    entry.append(r)
            else:
                entry.append((toknum, tokval))
        elif toknum == token.OP and tokval == start:
            if in_list:
                r = get_lists(token_stream, start, end, sep, potential_new, potential_end, True, False)
                if len(r) == 1:
                    entry.extend(r)
                else:
                    entry.append(r)
            else:
                in_list = True
        elif not only_list:
            results.append((toknum, tokval))
    return results

def detok(toks):
    if type(toks) == tuple:
        if toks[0] == token.STRING:
            return toks[1][1:-1]
        return toks[1]
    elif type(toks) == list:
        l = [detok(x) for x in toks]
        # TODO Maybe make this a more generic option?
        if len(l) > 2:
            if l[0] == 'IIngredientEmpty':
                return None
            # TODO Determine if we want to leave the *, use this, or something else
            #elif l[1] == '*' and len(l) == 3:
            #    print(l)
            #    return [l[0]] * int(l[2])
        return l
    return None

def parse_list(l, start, end, only_list=True):
    # Grab the arguments from the parenthesis
    tok_stream = tokenize.tokenize(BytesIO(tags_to_strs(l).encode('utf-8')).readline)
    res = get_lists(tok_stream, start, end, only_list=only_list)
    return res

def parse_args(funcCall):
    res = parse_list(funcCall, '(', ')', True)
    return detok(res)


def parse_recipe(r, rtype):
    if '~~ Recipe name:' in r:
        tokens = pull_tokens(r, ['Recipe name: ', ', Outputs: ', ', Inputs: ', ', Recipe Class: ', ', Recipe Serializer: ', ' ~~'])
        ret = {
            "name": tokens[0],
            "outputs": detok(tags_to_strs(tokens[1])),
            "inputs": parse_list(tokens[2], '[', ']'),
            "class": tokens[3],
            "serializer": tokens[4],
            "craft_type": None,
            "type": rtype,
            }
        return ret
    else:
        # Alternative recipe results
        # .addShaped
        # .addShapeless
        # .addRecipe
        if '.addShaped(' in r:
            args = parse_args(r)
            if len(args) < 3:
                raise Exception("Shaped recipe arg length < 3!", r, args)
            name = args[0]
            out = args[1]
            inputs = args[2]
            if len(args) > 3:
                raise Exception("Shaped recipe arg length > 3!", r, args)
            ret = {
                "name": name,
                "outputs": out,
                "inputs": inputs,
                "craft_type": "shaped",
                "type": rtype,
            }
            return ret
        elif '.addShapeless(' in r:
            args = parse_args(r)
            if len(args) < 3:
                raise Exception("Shapeless recipe arg length < 3!", r, args)
            name = args[0]
            out = args[1]
            inputs = args[2]
            if len(args) > 3:
                raise Exception("Shapeless recipe arg length > 3!", r, args)
            ret = {
                "name": name,
                "outputs": out,
                "inputs": inputs,
                "craft_type": "shapeless",
                "type": rtype,
            }
            return ret
        elif '.addRecipe(' in r:
            args = parse_args(r)
            if len(args) < 3:
                raise Exception("addRecipe arg length < 3!", r, args)
            name = args[0]
            out = args[1]
            inputs = args[2:]
            ret = {
                "name": name,
                "outputs": out,
                "inputs": inputs,
                "craft_type": None,
                "type": rtype,
            }
            return ret
        else:
            raise Exception("Unknown recipe type", r)
        return r

#tok_stream = tokenize.tokenize(BytesIO(tags_to_strs('''  craftingTable.addShaped(
#    "create_sa:andesite_exoskeleton_recipe", 
#    <item:create_sa:andesite_exoskeleton_chestplate>, 
#    [
#        [
#            <item:create:andesite_alloy>, 
#            <item:create:shaft>, 
#            <item:create:belt_connector>, 
#            <item:create:shaft>, 
#            <item:create:andesite_alloy>
#        ], 
#        [
#            <item:create:andesite_alloy>, 
#            <item:create:andesite_alloy>, 
#            <item:create_sa:heat_engine>, 
#            <item:create:andesite_alloy>, 
#            <item:create:andesite_alloy>
#        ], 
#        [
#            <tag:items:forge:stone>, 
#            <tag:items:forge:ingots/zinc>, 
#            <item:create:andesite_alloy>, 
#            <tag:items:forge:ingots/zinc>, 
#            <tag:items:forge:stone>
#        ]
#    ])''').encode('utf-8')).readline)
#res = get_lists(tok_stream, '(', ')', only_list=True)
#
#parse_args('''  craftingTable.addShaped(
#    "create_sa:andesite_exoskeleton_recipe", 
#    <item:create_sa:andesite_exoskeleton_chestplate>, 
#    [
#        [
#            <item:create:andesite_alloy>, 
#            <item:create:shaft>, 
#            <item:create:belt_connector>, 
#            <item:create:shaft>, 
#            <item:create:andesite_alloy>
#        ], 
#        [
#            <item:create:andesite_alloy>, 
#            <item:create:andesite_alloy>, 
#            <item:create_sa:heat_engine>, 
#            <item:create:andesite_alloy>, 
#            <item:create:andesite_alloy>
#        ], 
#        [
#            <tag:items:forge:stone>, 
#            <tag:items:forge:ingots/zinc>, 
#            <item:create:andesite_alloy>, 
#            <tag:items:forge:ingots/zinc>, 
#            <tag:items:forge:stone>
#        ]
#    ])''')


recipe_dict = {}
for r in recipe_types:
    rlist = r.rsplit('\n', 1)[0]
    rlist = rlist.split('\n')
    # First entry, skip "'<recipetype:" and cut the last ' off
    recipe_type = rlist[0][len("'<recipetype:"):-2]
    recipes = rlist[1:]
    #print(recipe_type, rlist[0])
    recipe_dict[recipe_type] = []
    for r in recipes:
        if len(r) == 0:
            continue
        if '[WARN]' in r:
            continue
        if 'Recipe List list generated! Check the logs/crafttweaker.log file!' in r:
            break
        parsed = parse_recipe(r,recipe_type)
        recipe_dict[recipe_type].append(parsed)
        #if parsed and '*' in r:
        #    print(parsed)
with open('recipes.json', 'w') as f:
    # To un-pretty the file, remove the indent
    json.dump(recipe_dict, f, indent=4)
