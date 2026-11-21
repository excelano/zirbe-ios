# Conversations

This is the definition of a conversation that every Zirbe app follows: the
iPhone and iPad app in this repository and the Linux desktop app,
[zirbe-desktop](https://github.com/excelano/zirbe-desktop). A change to these
rules is a change to this file and to both apps.

## What a conversation is

A conversation is an email thread, not a person. Messages are joined by the
RFC 5322 `Message-ID`, `In-Reply-To` and `References` headers: two messages
belong together when one names the other, or when both name the same message,
even one that was never received. The same person writing under five subjects
produces five conversations, which is correct email behavior. Subjects alone
never join messages.

A conversation reads like a named group chat. Its title is the subject of its
oldest message, with any `Re:`, `Fwd:` or `Fw:` prefixes removed. Its members are
everyone on `From`, `To` and `Cc` across its messages, the account's own
addresses aside. Its messages are bubbles in time order.

The account's own addresses are the one it signs in with and any others the
user lists for it in settings, such as aliases. They count as the user
everywhere these rules mention people.

## Private replies

A reply leaves its thread and starts a conversation of its own when it is
private to the message it answers. The message a reply answers is the one named
by its `In-Reply-To`, or failing that the newest message named in its
`References` that is held. Comparing the people on each, the account's own
addresses aside, the reply is private when it shares no one with the message it
answers, or when it goes to one person while that message went to several. An
answer to a message sent to many people by Bcc is the common case.

Replies to a private reply stay with it unless they are private in turn. The
new conversation shows the message it answers at its top as context. That
message still belongs to the conversation it came from, so archiving or
deleting the private conversation never moves it.

A reaction and an answer to a meeting invitation never split off, whoever they
go to. They stay with the message they answer.

## Copies

A message filed in more than one folder is one bubble in its conversation, and
each folder holding a copy shows the whole conversation. An action on a
conversation applies to the copies of its own messages, never to a context
message.

## Reactions

A reaction is a short reply to the message it reacts to, sent through the
user's own SMTP server like any other mail. It carries the emoji in an
`X-Zirbe-Reaction` header, encoded under RFC 2047 when the sender encodes it,
and a body such as "Reacted 👍 to …" naming the message, for mail programs that
show it as text. It answers its target through `In-Reply-To` and goes to
everyone in the conversation.

A Zirbe app shows a reaction as a badge on the message named by its
`In-Reply-To` rather than as a bubble. A newer reaction from the same person to
the same message replaces the earlier one.
