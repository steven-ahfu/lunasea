import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:lunasea/api/chaptarr/models.dart';

part 'api.g.dart';

@RestApi()
abstract class ChaptarrService {
  factory ChaptarrService(Dio dio, {String? baseUrl}) = _ChaptarrService;

  @GET('system/status')
  Future<ChaptarrStatus> status();

  @GET('book/paged')
  Future<ChaptarrLibraryPage> books(@Queries() Map<String, dynamic> query);

  @GET('book/{id}')
  Future<ChaptarrBook> book(@Path() int id);

  @GET('book/lookup')
  Future<List<ChaptarrBook>> lookup(@Query('term') String term);

  @GET('rootfolder')
  Future<List<ChaptarrRootFolder>> roots();

  @POST('book/import')
  Future<ChaptarrCreatedBook> addBook(@Body() Map<String, dynamic> book);

  @PUT('book/monitor')
  Future<void> monitor(@Body() Map<String, dynamic> selection);

  @POST('command')
  Future<void> command(@Body() Map<String, dynamic> command);

  @GET('queue')
  Future<ChaptarrQueuePage> queue(@Queries() Map<String, dynamic> query);

  @GET('history')
  Future<ChaptarrHistoryPage> history(@Queries() Map<String, dynamic> query);
}
