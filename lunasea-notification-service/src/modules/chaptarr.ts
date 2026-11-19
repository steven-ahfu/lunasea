import express from 'express';
import { Middleware } from '../server';
import { Ntfy } from '../services';
import { Constants, Notifications } from '../utils';

const events = new Map<string, string>([
  ['Grab', 'Release grabbed'],
  ['Download', 'Book imported'],
  ['Rename', 'Files renamed'],
  ['Retag', 'Files retagged'],
  ['BookAdded', 'Book added'],
  ['BookDelete', 'Book removed'],
  ['BookFileDelete', 'Book file removed'],
  ['AuthorAdded', 'Author added'],
  ['AuthorDelete', 'Author removed'],
  ['ApplicationUpdate', 'Chaptarr updated'],
  ['Health', 'Health issue'],
  ['Test', 'Connection test'],
]);

interface Book {
  id?: number;
  title?: string;
}
interface Webhook {
  eventType?: string;
  book?: Book;
  books?: Book[];
  author?: { name?: string };
  release?: { releaseTitle?: string };
  message?: string;
  isUpgrade?: boolean;
}

export function payload(data: Webhook, profile: string): Notifications.Payload | undefined {
  const event = data.eventType;
  if (!event || !events.has(event)) return undefined;
  const book = data.book ?? data.books?.[0];
  const label = event === 'Download' && data.isUpgrade ? 'Book upgraded' : events.get(event)!;
  const titles =
    data.books
      ?.map((b) => b.title)
      .filter(Boolean)
      .join(', ') || book?.title;
  return {
    title: Notifications.generateTitle('Chaptarr', profile, label),
    body:
      [titles, data.author?.name, data.message || data.release?.releaseTitle]
        .filter(Boolean)
        .join('\n') || label,
    data: { module: 'chaptarr', profile, event, ...(book?.id ? { id: String(book.id) } : {}) },
  };
}

export function enable(api: express.Router): void {
  api.post('/chaptarr/:topic', Middleware.extractTopic, async (request, response) => {
    const notice = payload(request.body ?? {}, response.locals.profile);
    if (
      notice &&
      !(await Ntfy.publish(response.locals.topic, notice, response.locals.notificationSettings))
    ) {
      response.status(502).json({ message: 'Notification delivery failed' });
      return;
    }
    response.status(200).json({ message: Constants.MESSAGE.OK });
  });
}
