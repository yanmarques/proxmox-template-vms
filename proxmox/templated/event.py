from .utils import logger


class EventNotExists(Exception):
    def __init__(self, event):
        super().__init__(f'Unable to find event by name: {event}')


class TooManyListeners(Exception):
    def __init__(self, event):
        super().__init__(f'Event has more than one listener: {event}')


class EventIsRestricted(Exception):
    def __init__(self, event):
        super().__init__(f'Event only accepts 1 listener: {event}')

    
class EventAlreadyExists(Exception):
    def __init__(self, event):
        super().__init__(f'Specified event already exists: {event}')


class Dispatcher:
    def __init__(self, listeners: dict = {}):
        self._listeners = listeners
        self._restricteds = []

    def dispatch(self, event):
        handlers = self.handlers_or_fail(event)

        logger.info('received event [%s]', event)

        if self.is_restricted(event):
            # event listeners are removed
            self.remove_event(event)

            logger.debug('restricted event [%s]', event)
            handler = handlers[0]
            return handler()

        # event listeners are removed
        self.remove_event(event)
        
        for handler in handlers:
            handler()
    
    def restrict_existing_event(self, event):
        if self.is_restricted(event):
            return
        
        handlers = self.handlers_or_fail(event)
        if len(handlers) != 1:
            raise TooManyListeners(event)

        self._restricteds.append(event)

    def restrict_event(self, event, handler):
        if self.has_event(event):
            raise EventAlreadyExists(event)

        self.listen(event, handler)
        self.restrict_existing_event(event)

    def is_restricted(self, event):
        return event in self._restricteds

    def listen(self, event, handler):
        if self.is_restricted(event):
            raise EventIsRestricted(event)

        self._ensure_exists(event, handler)

    def has_event(self, event):
        handlers = self._listeners.get(event)
        return handlers is not None

    def remove_event(self, event):
        self._listeners[event] = None

    def handlers_or_fail(self, event):
        if not self.has_event(event):
            raise EventNotExists(event)
        return self._listeners.get(event)

    def _ensure_exists(self, event, handler):
        if not self.has_event(event):
            self._listeners[event] = []
        self._listeners[event].append(handler)