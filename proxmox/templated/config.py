import os


class CommonCfg:
    '''
    Handle common promox data format I/O.
    '''

    def __init__(self, path):
        self._path = path

    def write(self, data_dict):
        '''
        Write data dictionary object in a common format.
        '''

        content = (f'{k}: {v}\n' for k, v in data_dict.items())

        with open(self._path, 'w') as wr:
            return wr.write(''.join(content))

    def read(self):
        ''' 
        Parses given file using common proxmox configuration syntax.
        '''

        with open(self._path) as r:
            data = r.read()

        cfg = {}
        for _line in data.split('\n'):
            line = _line.strip()
            if line:
                key, value = line.split(':')
                cfg[key] = value.strip()
        return cfg


class ConfigIOInterface:
    def __init__(self, path, load=False):
        self._cfg_handler = CommonCfg(path)
        self._stats = None
        if load:
            self.reload()

    def last(self, key, default=None):
        return self._stats.get(key, default)

    def get(self, *args, **kwargs):
        return self.last(*args, **kwargs)

    def put(self, key, value):
        self._stats[key] = value
        self._flush()

    def update(self, **kwargs):
        self._stats.update(**kwargs)
        self._flush()

    def seen(self, key):
        return key in self._stats

    def delete(self, key):
        if self.seen(key):
            del self._stats[key]
            self._flush()

    def _flush(self):
        self._cfg_handler.write(self._stats)

    def reload(self):
        if os.path.exists(self._cfg_handler._path):
            self._stats = self._cfg_handler.read()
        else:
            self._stats = dict()