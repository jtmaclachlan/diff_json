import logging
from .mapping import JSONMap
from .xpath import XPathMatch


logger = logging.getLogger("diff_json")


class JSONDiff:
    def __init__(self, old_json, new_json, ignore_paths=None, count_paths=None, track_array_moves=True,
                 track_structure_updates=False, replace_primitives_arrays=False):
        self.old_map = JSONMap(old_json)
        self.new_map = JSONMap(new_json)
        self.ignore_paths = set()
        self.count_paths = {}

        if ignore_paths:
            self.ignore_paths = set(map(XPathMatch.from_path_string, ignore_paths))

        if count_paths:
            for match_string in count_paths:
                self.count_paths[XPathMatch.from_path_string(match_string)] = count_paths[match_string]
        else:
            self.count_paths["/**"] = ["add", "remove", "replace", "move", "update"]

        self.ordered, self.shared, self.added, self.dropped, self.ignored = self.__gather_paths()
        self.track_array_moves = track_array_moves
        self.track_structure_updates = track_structure_updates
        self.replace_primitives_arrays = replace_primitives_arrays
        self.diff = {}

    def run(self):
        for xpath in self.ordered:
            if xpath not in self.ignored:
                logger.debug(f"PROCESS {xpath}")
                if xpath in self.shared:
                    logger.debug("SHARED")
                    self.__diff_element(xpath)
                elif xpath in self.added:
                    logger.debug("ADDED")
                    self.__handle_added_element(xpath)
                else:
                    logger.debug("REMOVED")
                    self.__handle_removed_element(xpath)

    def get_patch(self):
        patch = []

        for xpath in self.diff:
            patch.extend(self.diff[xpath])

        return patch

    def __gather_paths(self):
        omxs = set(self.old_map.xpaths())
        nmxs = set(self.new_map.xpaths())
        all_xpaths = omxs | nmxs
        ordered = sorted(all_xpaths)
        shared = omxs & nmxs
        added = nmxs - shared
        dropped = omxs - shared
        ignored = set()

        for xpath in ordered:
            for ipath in self.ignore_paths:
                if ipath.matches_path(xpath):
                    ignored.add(xpath)
                    break

        return [ordered, shared, added, dropped, ignored]

    def __add_element_sub_path_ignores(self, xpath):
        logger.debug(f"Add sub-element ignores for {xpath}/**")
        new_ignored = xpath.to_match("**").find_matches(self.ordered)
        self.ignored = self.ignored | set(new_ignored)

    def __get_shared_path_elements(self, xpath):
        return {
            'old': self.old_map[xpath],
            'new': self.new_map[xpath]
        }

    def __register_operation(self, xpath, op, value=None):
        operation = {'op': op, 'path': xpath.path}

        if op in ["add", "replace"]:
            operation['value'] = value

        if xpath in self.diff:
            self.diff[xpath].append(operation)
        else:
            self.diff[xpath] = [operation]

    def __replace_array(self, old_array, new_array):
        return self.replace_primitives_arrays \
               and old_array.array_type == "primitives" \
               and new_array.array_type == "primitives"

    def __find_array_moves(self, xpath, old_array, new_array):
        index_paths = xpath.to_match("*").find_matches(self.ordered)
        logger.debug(list(map(str, index_paths)))
        old_elements = set(self.old_map.get_elements(index_paths))
        new_elements = set(self.new_map.get_elements(index_paths))
        shared_elements = (old_elements & new_elements)
        old_move_check = sorted(old_elements - shared_elements)
        new_move_check = new_elements - shared_elements
        print(old_move_check)
        print(new_move_check)
        max_possible_moves = min(len(old_move_check), len(new_move_check))

        if max_possible_moves > 0:
            found_movements = [{'old': oe, 'new': ne}
                               for oe in old_move_check
                               for ne in new_move_check
                               if oe.value_hash == ne.value_hash]

            for move in found_movements:
                self.__register_operation()
            print(found_movements)
    
    def __diff_element(self, xpath):
        elements = self.__get_shared_path_elements(xpath)
        diff_type = self.__get_diff_type(elements)
        logger.debug(f"DIFF TYPE: {diff_type}")

        match diff_type:
            case "equal":
                if elements['old'].json_type != "primitive":
                    self.__add_element_sub_path_ignores(xpath)
            case "replace":
                self.__register_operation(xpath, "replace", value=elements['new'].value)

                if elements['old'].json_type != "primitive" or elements['new'].json_type != "primitive":
                    self.__add_element_sub_path_ignores(xpath)
            case "diff/array":
                if self.track_structure_updates:
                    self.__register_operation(xpath, "update")

                if self.__replace_array(elements['old'], elements['new']):
                    self.__register_operation(xpath, "replace", value=elements['new'].value)
                    self.__add_element_sub_path_ignores(xpath)
                    return

                if self.track_array_moves:
                    self.__find_array_moves(xpath, elements['old'], elements['new'])
            case "diff/object":
                if self.track_structure_updates:
                    self.__register_operation(xpath, "update")
            case "diff/primitive":
                self.__register_operation(xpath, "replace", value=elements['new'].value)
    
    def __handle_added_element(self, xpath):
        element = self.new_map[xpath]
        self.__register_operation(xpath, "add", element.value)

        if element.json_type != "primitive":
            self.__add_element_sub_path_ignores(xpath)
    
    def __handle_removed_element(self, xpath):
        element = self.old_map[xpath]
        self.__register_operation(xpath, "remove")

        if element.json_type != "primitive":
            self.__add_element_sub_path_ignores(xpath)

    @staticmethod
    def __get_diff_type(elements):
        if elements['old'] == elements['new']:
            return "equal"

        if elements['old'].json_type == elements['new'].json_type:
            return f"diff/{elements['old'].json_type}"

        return "replace"
