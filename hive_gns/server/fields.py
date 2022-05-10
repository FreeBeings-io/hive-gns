class Fields:
    """Main class to hold fields for SQL queries made by endpoints."""

    class Global:
        """Global SQL fields."""
        @classmethod
        def get_all_notifs(cls, extra=None):
            """Fields for the `_get_all_notifs()` global endpoint function."""
            res = ['created', 'remark']
            if extra:
                return res.extend(extra)
            else:
                return res

    class Core:
        """Core module SQL fields."""
        @classmethod
        def get_transfers(cls, extra=None):
            """Fields for the `_get_transfers()` core endpoint function."""
            res = ['created', 'remark']
            if extra:
                return res.extend(extra)
            else:
                return res
        
        @classmethod
        def get_preferences(cls):
            """Fields for the `_get_preferences()` core endpoint function."""
            res = ['prefs', 'prefs_updated']
            return res
    
    class Splinterlands:
        """Splinterlands module's SQL fields."""
        @classmethod
        def get_transfers(cls, extra=None):
            """Field for the `_get_transfers()` Splinterlands endpoint function."""
            res = ['created', 'remark']
            if extra:
                return res.extend(extra)
            else:
                return res
