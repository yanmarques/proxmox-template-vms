from templated import (
    event
)
import pytest

from unittest import mock


def test_event_is_registered():
    d = event.Dispatcher()
    fake_fn = mock.Mock()

    d.listen('foo', fake_fn)
    d.dispatch('foo')
    
    fake_fn.asset_has_calls()


def test_event_is_removed_after_dispatched():
    d = event.Dispatcher()

    d.listen('foo', mock.Mock())
    d.dispatch('foo')

    assert d.has_event('foo') is False


def test_restricted_event_returns_handler():
    d = event.Dispatcher()
    expected = 'baz'

    d.restrict_event('foo', mock.Mock(return_value=expected))
    result = d.dispatch('foo')

    assert result == expected
    

def test_fails_to_restrict_existing_event():
    d = event.Dispatcher()
    
    d.listen('foo', mock.Mock())

    with pytest.raises(event.EventAlreadyExists):
        d.restrict_event('foo', 'any')


def test_fails_to_restrict_event_with_too_many_listeners():
    d = event.Dispatcher()
    
    d.listen('foo', mock.Mock())
    d.listen('foo', mock.Mock())

    with pytest.raises(event.TooManyListeners):
        d.restrict_existing_event('foo')