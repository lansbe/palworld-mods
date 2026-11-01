"""Bound catalogue I/O to directory descriptors without following input links."""
import os
import pathlib
import secrets
import stat

MAX_BYTES = 1_048_576
MAX_ENTRIES = 512
DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC


def anchored_directory(path):
    # The caller supplies the trusted parent (including system aliases such as
    # /var). The checkout/output root itself and every descendant are no-follow.
    path = pathlib.Path(path).absolute()
    if path.name in {'', '.', '..'}:
        raise ValueError('Invalid package directory')
    parent = os.open(path.parent.resolve(strict=True), DIRECTORY_FLAGS)
    try:
        return os.open(path.name, DIRECTORY_FLAGS, dir_fd=parent)
    finally:
        os.close(parent)


class SourceTree:
    def __init__(self, folder):
        self.fd = anchored_directory(folder)
        self.bytes = 0
        self.entries = 0

    def __enter__(self):
        return self

    def __exit__(self, *_):
        os.close(self.fd)

    def directory(self, path):
        parts = pathlib.PurePath(path).parts
        if pathlib.PurePath(path).is_absolute() or not parts or '..' in parts:
            raise ValueError('Invalid package input path')
        fd = os.dup(self.fd)
        try:
            for part in parts:
                child = os.open(part, DIRECTORY_FLAGS, dir_fd=fd)
                os.close(fd)
                fd = child
            return fd
        except BaseException:
            os.close(fd)
            raise

    def has_directory(self, path):
        try:
            fd = self.directory(path)
        except FileNotFoundError:
            return False
        os.close(fd)
        return True

    def read_file(self, parent, name):
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC, dir_fd=parent)
        try:
            info = os.fstat(fd)
            limit = min(MAX_BYTES, MAX_BYTES - self.bytes)
            if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_size > limit:
                raise ValueError('Package input must be a bounded single-link regular file')
            chunks, size = [], 0
            while True:
                chunk = os.read(fd, min(65536, limit + 1 - size))
                if not chunk:
                    break
                chunks.append(chunk)
                size += len(chunk)
                if size > limit:
                    raise ValueError('Package input exceeds the size limit')
            self.bytes += size
            return b''.join(chunks).decode('utf-8')
        finally:
            os.close(fd)

    def read_text(self, path):
        path = pathlib.PurePath(path)
        if path.is_absolute() or not path.parts or '..' in path.parts:
            raise ValueError('Invalid package input path')
        parent = self.directory(path.parent) if path.parent.parts else os.dup(self.fd)
        try:
            return self.read_file(parent, path.name)
        finally:
            os.close(parent)

    def lua_files(self):
        def walk(fd, parts):
            if len(parts) > 16:
                raise ValueError('Package directory depth limit')
            for name in sorted(os.listdir(fd)):
                self.entries += 1
                if self.entries > MAX_ENTRIES:
                    raise ValueError('Package entry count limit')
                info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                if stat.S_ISDIR(info.st_mode):
                    child = os.open(name, DIRECTORY_FLAGS, dir_fd=fd)
                    try:
                        yield from walk(child, parts + (name,))
                    finally:
                        os.close(child)
                elif not stat.S_ISREG(info.st_mode):
                    raise ValueError('Package source contains a link or special file')
                elif name.endswith('.lua'):
                    module = '.'.join((*parts, name[:-4]))
                    yield module, self.read_file(fd, name)
        fd = self.directory('src')
        try:
            yield from walk(fd, ())
        finally:
            os.close(fd)


def write_catalogue(output, identifier, data, digest):
    fd = anchored_directory(output)
    temporary = []
    try:
        contents = [(identifier + '.json', data), (identifier + '.sha256', digest)]
        # Reject either link before changing either output. Later replacements
        # replace the directory entry atomically, never truncate its target.
        for name, _ in contents:
            try:
                info = os.stat(name, dir_fd=fd, follow_symlinks=False)
            except FileNotFoundError:
                continue
            if not stat.S_ISREG(info.st_mode):
                raise ValueError('Package output must be a regular file')
        for name, content in contents:
            staging = '.catalog-' + secrets.token_hex(16)
            target = os.open(staging, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=fd)
            temporary.append(staging)
            with os.fdopen(target, 'wb') as stream:
                stream.write(content)
                stream.flush()
                os.fchmod(stream.fileno(), 0o644)
                os.fsync(stream.fileno())
            os.replace(staging, name, src_dir_fd=fd, dst_dir_fd=fd)
            temporary.remove(staging)
    finally:
        for name in temporary:
            os.unlink(name, dir_fd=fd)
        os.close(fd)
