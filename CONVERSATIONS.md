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
never join messages; the one place a subject counts is a reply that lost its
threading headers, below.

A conversation reads like a named group chat. Its title is the subject of its
oldest message, with its reply and forward prefixes removed: `Re:`, `AW:`,
`SV:`, `VS:`, `Antw:`, `Odp:`, `Ynt:` and `Rif:` mark a reply, and `Fwd:`,
`Fw:` and `WG:` a forward, each with or without a counter such as `Re[2]:`.
Its members are everyone on `From`, `To` and `Cc` across its messages, the
account's own addresses aside. Its messages are bubbles in time order.

The account's own addresses are the one it signs in with and any others the
user lists for it in settings, such as aliases. They count as the user
everywhere these rules mention people.

## A reply that lost its threading headers

Some mail programs reply without `In-Reply-To` or `References`, and a reply's
parent can be missing from what an app holds. Such a message joins an existing
conversation when all of these hold: its subject starts with a reply prefix,
not a forward; none of its threading headers names a message held; its subject
without prefixes equals the conversation's title; its people, the account's own
addresses aside, are exactly the conversation's members; and the conversation
has a message from the 30 days before it. Otherwise it starts a conversation of
its own.

## Mailing lists

A message carrying a `List-Id` header (RFC 2919) belongs to the conversation of
its list, one per list and account, whatever its threading headers say. So does
a message without one that is addressed, in `To` or `Cc`, to the list's posting
address from `List-Post` (RFC 2369), which is how the user's own posts join.
The conversation's title is the list's name from the `List-Id` phrase, or its
identifier when the phrase is empty. Its members are everyone on `From`, `To`
and `Cc` across its messages, the posting address and the account's own
addresses aside; a list conversation shows no notes of people joining or
leaving, and no reply inside it splits off.

A reply to the conversation goes to the list's posting address, with the
subject of the message it answers. A reaction goes only to the person who wrote
the message reacted to. A reply sent to that person alone, not to the list, is
a private reply under the rule below, with the list message as its context.

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

A reaction follows RFC 9078. It is a reply to the message it reacts to, sent
through the user's own SMTP server like any other mail, answering its target
through `In-Reply-To`. Its body is a single `text/plain; charset=utf-8` part
marked `Content-Disposition: reaction` and holding only the emoji. It goes to
everyone in the conversation, except in a mailing list, where it goes to the
target's author. A Zirbe app also writes the emoji in an `X-Zirbe-Reaction`
header, which earlier versions read, and reads that header when it is present.

A Zirbe app reads a reaction from a message that has `In-Reply-To` and a part
marked `Content-Disposition: reaction`, either its whole body or the first part
of a multipart body. It shows the reaction as a badge on the message named by
`In-Reply-To` rather than as a bubble. A newer reaction from the same person to
the same message replaces the earlier one, and an empty one withdraws it.
